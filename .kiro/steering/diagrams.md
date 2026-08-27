# Diagram Standards

- All diagrams MUST be created in **Mermaid markdown format** (```mermaid code blocks).
- Mermaid is chosen for maximum compatibility — it renders natively on:
  - Kiro IDE
  - VS Code (built-in Markdown preview)
  - GitHub (README, issues, PRs, wikis)
  - GitLab (README, issues, MRs, wikis)
- Do NOT use image-based diagrams (PNG/SVG/draw.io) unless the user explicitly requests a different format.
- Place diagram files as `.md` files in the relevant directory (e.g., `deployment/diagram/`).
- Use appropriate Mermaid diagram types for the context:
  - `flowchart` or `graph` for architecture and flow diagrams
  - `sequenceDiagram` for request/response flows
  - `erDiagram` for database schemas
  - `classDiagram` for class relationships
  - `stateDiagram-v2` for state machines
