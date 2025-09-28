#!/usr/bin/env bash
# Recon Uruz - lightweight reconnaissance helper for workflow automation.
# Collects WHOIS, DNS, HTTP, TLS and port scan information for a target domain
# and packages the findings into a timestamped archive under ./output.

set -uo pipefail

show_usage() {
  cat <<'USAGE' >&2
Usage: recon_uruz.sh <domain>

Collect reconnaissance data for the provided domain and save the results in
./output/<domain>_<timestamp>.tar.gz
USAGE
}

if [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
  show_usage
  exit 0
fi

if [[ $# -lt 1 || -z ${1-} ]]; then
  echo "[!] Missing target domain." >&2
  show_usage
  exit 1
fi

DOMAIN=$1
TIMESTAMP=$(date -u +%Y%m%d-%H%M%SZ)
SAFE_DOMAIN=$(echo "$DOMAIN" | tr -cd '[:alnum:]._-')
BASE_DIR="output/${SAFE_DOMAIN}_${TIMESTAMP}"
mkdir -p "$BASE_DIR"

log_step() {
  printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$1"
}

run_and_capture() {
  local name="$1"
  shift
  local outfile="$BASE_DIR/${name}.txt"
  log_step "Collecting ${name}"
  {
    printf '$'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    local status=0
    if "$@"; then
      status=0
    else
      status=$?
    fi
    if [[ $status -eq 0 ]]; then
      printf '\n[success] %s\n' "$name"
    else
      printf '\n[error] %s (exit %d)\n' "$name" "$status"
    fi
  } >"$outfile" 2>&1
}

# Metadata
{
  echo "domain=${DOMAIN}"
  echo "timestamp=${TIMESTAMP}"
  echo "host=$(hostname)"
  echo "kernel=$(uname -sr)"
} >"$BASE_DIR/metadata.txt"

# WHOIS information
run_and_capture whois_info whois "$DOMAIN"

# DNS records with dig
run_and_capture dns_a dig "$DOMAIN" A +noall +answer
run_and_capture dns_aaaa dig "$DOMAIN" AAAA +noall +answer
run_and_capture dns_ns dig "$DOMAIN" NS +noall +answer
run_and_capture dns_mx dig "$DOMAIN" MX +noall +answer
run_and_capture dns_txt dig "$DOMAIN" TXT +noall +answer
run_and_capture dns_soa dig "$DOMAIN" SOA +noall +answer

# Attempt zone transfer from each nameserver (best-effort)
if command -v dig >/dev/null 2>&1; then
  log_step "Attempting zone transfer"
  {
    printf '$ %s\n' "dig @$DOMAIN AXFR"
    mapfile -t ns_list < <(dig "$DOMAIN" NS +short)
    if [[ ${#ns_list[@]} -eq 0 ]]; then
      echo "No nameservers found."
    else
      for ns in "${ns_list[@]}"; do
        echo "# dig @${ns} ${DOMAIN} AXFR"
        if dig "@$ns" "$DOMAIN" AXFR +noall +answer; then
          echo
        else
          echo "(failed)"
          echo
        fi
      done
    fi
  } >"$BASE_DIR/dns_zone_transfer.txt" 2>&1
else
  echo "dig command not available" >"$BASE_DIR/dns_zone_transfer.txt"
fi

# host and nslookup summaries
run_and_capture host_all host -a "$DOMAIN"
run_and_capture nslookup_default nslookup "$DOMAIN"

# Resolve IP addresses for targeted scans
RESOLVED_IPS=()
if command -v dig >/dev/null 2>&1; then
  mapfile -t RESOLVED_IPS < <(dig +short "$DOMAIN" A)
fi

# Nmap scans
if command -v nmap >/dev/null 2>&1; then
  run_and_capture nmap_top100 nmap -Pn -T4 --top-ports 100 "$DOMAIN"
  if [[ ${#RESOLVED_IPS[@]} -gt 0 ]]; then
    for ip in "${RESOLVED_IPS[@]}"; do
      run_and_capture "nmap_service_${ip}" nmap -Pn -sV -T4 "$ip"
    done
  fi
else
  echo "nmap not available" >"$BASE_DIR/nmap_top100.txt"
fi

# TLS certificate details
if command -v openssl >/dev/null 2>&1; then
  log_step "Gathering TLS information"
  {
    printf '$ %s\n' "timeout 20 openssl s_client -servername ${DOMAIN} -connect ${DOMAIN}:443"
    if timeout 20 openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 -showcerts </dev/null; then
      echo
    else
      echo "(TLS connection failed)"
    fi
  } >"$BASE_DIR/tls_handshake.txt" 2>&1

  log_step "Extracting leaf certificate"
  {
    printf '$ %s\n' "timeout 20 openssl s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 | openssl x509 -noout -text"
    if timeout 20 openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 </dev/null | openssl x509 -noout -text; then
      echo
    else
      echo "(certificate parse failed)"
    fi
  } >"$BASE_DIR/tls_certificate.txt" 2>&1
fi

# HTTP headers and responses
if command -v curl >/dev/null 2>&1; then
  run_and_capture http_headers_http curl -I --max-time 15 "http://$DOMAIN"
  run_and_capture http_headers_https curl -I -k --max-time 15 "https://$DOMAIN"
  run_and_capture http_homepage curl -k --max-time 20 -L "https://$DOMAIN"
fi

# Fetch certificate transparency entries from crt.sh (best effort)
CRT_JSON="$BASE_DIR/crtsh_raw.json"
CRT_LOG="$BASE_DIR/crtsh_lookup.txt"
CRT_OUT="$BASE_DIR/crtsh_hosts.txt"
if command -v curl >/dev/null 2>&1; then
  log_step "Querying crt.sh"
  {
    printf '$ %s\n' "curl -s https://crt.sh/?q=%25.${DOMAIN}&output=json -o ${CRT_JSON}"
    if curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json" -o "$CRT_JSON"; then
      echo "[success] crt.sh lookup"
    else
      status=$?
      echo "[error] crt.sh lookup (exit ${status})"
    fi
  } >"$CRT_LOG" 2>&1

  log_step "Extracting hostnames from crt.sh"
  CRT_IN="$CRT_JSON"
  if command -v python3 >/dev/null 2>&1; then
    export CRT_OUTFILE="$CRT_OUT"
    export CRT_INPUT="$CRT_IN"
    {
      printf '$ %s\n' "python3 -"
      python3 <<'PY'
import json
import os
import sys
from collections import Counter

outfile = os.environ.get("CRT_OUTFILE")
input_file = os.environ.get("CRT_INPUT")
if not outfile or not input_file:
    sys.exit(0)
try:
    with open(input_file, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"failed to parse JSON: {exc}")
    sys.exit(0)

names = []
for entry in data:
    name_value = entry.get("name_value")
    if not name_value:
        continue
    for host in str(name_value).split("\n"):
        host = host.strip()
        if host:
            names.append(host.lower())

counts = Counter(names)
for host, count in counts.most_common():
    print(f"{host} {count}")
PY
    } >"$CRT_OUT" 2>&1
    unset CRT_OUTFILE CRT_INPUT
  else
    echo "python3 command not available" >"$CRT_OUT"
  fi
else
  echo "curl command not available" >"$CRT_LOG"
  : >"$CRT_JSON"
  echo "curl command not available" >"$CRT_OUT"
fi

# Summaries
cat <<'SUMMARY' >"$BASE_DIR/README.txt"
Recon Uruz report
=================
Domain: ${DOMAIN}
Generated at (UTC): ${TIMESTAMP}

Artifacts
---------
- whois_info.txt: WHOIS output
- dns_*.txt: DNS record lookups
- dns_zone_transfer.txt: AXFR attempts for discovered nameservers
- host_all.txt / nslookup_default.txt: additional DNS tooling output
- nmap_top100.txt and nmap_service_*.txt: port and service scans
- tls_handshake.txt / tls_certificate.txt: TLS session and certificate data
- http_headers_http.txt / http_headers_https.txt / http_homepage.txt: HTTP responses
- crtsh_raw.json / crtsh_hosts.txt: Certificate transparency enumeration results
- metadata.txt: execution metadata
SUMMARY

# Create archive
ARCHIVE_PATH="output/${SAFE_DOMAIN}_${TIMESTAMP}.tar.gz"
tar -czf "$ARCHIVE_PATH" -C "$BASE_DIR" .
log_step "Archive created at ${ARCHIVE_PATH}"

echo "Recon complete."
