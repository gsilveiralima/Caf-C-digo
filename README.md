# AulaPlay — Time Café & Código (MVP)

Microaulas gamificadas com IA para EaD. Este repositório contém um protótipo offline (HTML/CSS/JS) pronto para demonstração.

## Rodar local
1. Abra `index.html` no navegador.
2. Clique em **Testar Demo** para jogar.
3. Apresente pelo `docs/pitch.html`.

## Ferramentas de desenvolvimento
- Instale a CLI Codex globalmente para auxiliar na prototipação com IA:
  ```bash
  npm install -g @openai/codex
  ```

## Estrutura
- `index.html` — landing do produto
- `demo.html` — demonstração do quiz
- `css/` — estilos
- `js/` — lógica do quiz
- `data/subjects.json` — conteúdo de exemplo
- `docs/pitch.html` — slides do pitch
- `docs/manual.html` — manual

## Roadmap técnico (pós-hack)
- IA (Gemini/Bedrock) para gerar questões e feedback
- RAG com PDFs (chunking + embeddings + busca vetorial)
- Autenticação (SSO), perfis de acesso e LGPD
- Analytics e exportação para Moodle/Google Classroom

## Licença
Uso acadêmico para o Gran Hackathon 2025.
