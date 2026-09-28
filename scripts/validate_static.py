import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: str) -> Path:
    target = ROOT / path
    if not target.is_file():
        raise SystemExit(f"Arquivo obrigatório ausente: {path}")
    return target


def main() -> None:
    for path in [
        "index.html",
        "demo.html",
        "css/styles.css",
        "js/app.js",
        "data/subjects.json",
        "docs/pitch.html",
        "docs/contatos.json",
        "assets/logo.svg",
        "assets/cover.png",
    ]:
        require(path)

    with require("data/subjects.json").open(encoding="utf-8") as file:
        subjects = json.load(file)
    if not isinstance(subjects, dict) or not subjects:
        raise SystemExit("data/subjects.json deve conter ao menos um tema.")

    with require("docs/contatos.json").open(encoding="utf-8") as file:
        contacts = json.load(file)
    if not isinstance(contacts, list) or not contacts:
        raise SystemExit("docs/contatos.json deve conter a equipe.")

    for path in ["index.html", "docs/pitch.html", "docs/contatos.html"]:
        text = require(path).read_text(encoding="utf-8")
        if "@exemplo.com" in text:
            raise SystemExit(f"Contato fictício encontrado em {path}.")
        if "\\1" in text or "\\3" in text:
            raise SystemExit(f"Marcador de substituição inválido encontrado em {path}.")

    print("Validação estática concluída com sucesso.")


if __name__ == "__main__":
    main()
