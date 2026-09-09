# Product documentation — Keel AI

This folder explains **what Keel is and how to use it**, for someone who manages several projects and a large team of agents and wants to understand the tool end-to-end without having to read the code or the 37 feature notes one by one.

It is self-contained: each file can be read alone, and the diagrams are Mermaid (plain text, no dependencies). When a statement describes concrete behavior of the app, it carries a relative link to the document in `../features/` that backs it up — that folder remains the source of technical truth; this is the entry point.

There are no images or embedded screenshots in any file in this folder. Where it makes sense to see the real interface, it is linked as text to one of the three HTML mockups in `../mockup/` (`proyectos-y-requerimientos.html`, `integraciones-tableros-y-maquina.html`, `mapa-de-razonamiento.html`), built with the exact tokens of the app's theme — open them in a browser to see the drawing.

## Reading map

| If you're... | Start with |
|---|---|
| Someone who has never used Keel and wants the big picture | [01 — What is Keel](01-what-is-keel.md) |
| Someone opening the app for the first time | [02 — Front-end and navigation](02-front-end-and-navigation.md) |
| Someone setting up projects and work sessions | [03 — Projects, sessions, and workflows](03-projects-sessions-and-workflows.md) |
| Someone building agent teams and wants to see work in action | [04 — Delegation and teams](04-delegation-and-teams.md) |
| Someone managing several projects at once | [05 — Multiple projects](05-multiple-projects.md) |
| Someone configuring agents, skills, rules, and hooks | [06 — Agents, skills, rules, and hooks](06-agents-skills-rules-hooks.md) |
| Someone connecting external integrations or using codex alongside claude | [07 — MCPs, integrations, and providers](07-mcps-integrations-and-providers.md) |
| Someone wanting to take configuration to another machine or share it | [08 — Import, export, and packages](08-import-export-and-packages.md) |
| Someone wanting to see complete end-to-end cases | [09 — Operational flows](09-operational-flows.md) |
| Someone coming from Claude Code, Codex CLI, Cursor, or Windsurf | [10 — Differences from other tools](10-differences-from-other-tools.md) |

## Complete index

1. [What is Keel](01-what-is-keel.md)
2. [Front-end and navigation](02-front-end-and-navigation.md)
3. [Projects, sessions, and workflows](03-projects-sessions-and-workflows.md)
4. [Delegation and teams](04-delegation-and-teams.md)
5. [Multiple projects](05-multiple-projects.md)
6. [Agents, skills, rules, and hooks](06-agents-skills-rules-hooks.md)
7. [MCPs, integrations, and providers](07-mcps-integrations-and-providers.md)
8. [Import, export, and packages](08-import-export-and-packages.md)
9. [Operational flows](09-operational-flows.md)
10. [Differences from other tools](10-differences-from-other-tools.md)

For technical detail feature by feature, see [`../features/`](../README.md).
For how the app is compiled and distributed, see
[`../build-and-distribute.md`](../build-and-distribute.md).
