# Documentación de producto — Keel AI

Esta carpeta explica **qué es Keel y cómo se usa**, para alguien que gestiona varios proyectos y un equipo grande de agentes y quiere entender la herramienta de punta a punta sin tener que leer el código ni las 37 notas de feature una por una.

Es autocontenida: cada archivo se puede leer solo, y los diagramas son Mermaid (texto plano, sin dependencias). Cuando una afirmación describe un comportamiento concreto de la app, lleva un enlace relativo al documento de `../features/` que lo sostiene — esa carpeta sigue siendo la fuente de verdad técnica; esto es la puerta de entrada.

No hay imágenes ni capturas embebidas en ningún archivo de esta carpeta. Donde conviene ver la interfaz real, se enlaza como texto a uno de los tres mockups HTML de `../mockup/` (`proyectos-y-requerimientos.html`, `integraciones-tableros-y-maquina.html`, `mapa-de-razonamiento.html`), construidos con los tokens exactos del tema de la app — abrilos en un navegador para ver el dibujo.

## Mapa de lectura

| Si sos... | Empezá por |
|---|---|
| Alguien que nunca usó Keel y quiere el panorama general | [01 — Qué es Keel](01-que-es-keel.md) |
| Alguien que va a abrir la app por primera vez | [02 — El front y la navegación](02-front-y-navegacion.md) |
| Quien va a armar proyectos y sesiones de trabajo | [03 — Proyectos, sesiones y workflows](03-proyectos-sesiones-y-workflows.md) |
| Quien arma equipos de agentes y quiere ver el trabajo en vivo | [04 — Delegación y equipos](04-delegacion-y-equipos.md) |
| Quien gestiona varios proyectos a la vez | [05 — Múltiples proyectos](05-multiples-proyectos.md) |
| Quien configura agentes, skills, reglas y hooks | [06 — Agentes, skills, reglas y hooks](06-agentes-skills-reglas-hooks.md) |
| Quien conecta integraciones externas o usa codex además de claude | [07 — MCPs, integraciones y proveedores](07-mcps-integraciones-y-proveedores.md) |
| Quien quiere llevarse configuración a otra máquina o compartirla | [08 — Importación, exportación y paquetes](08-importacion-exportacion-paquetes.md) |
| Quien quiere ver casos completos de punta a punta | [09 — Flujos operativos](09-flujos-operativos.md) |
| Quien viene de Claude Code, Codex CLI, Cursor o Windsurf | [10 — Diferencias con otras herramientas](10-diferencias-con-otros.md) |

## Índice completo

1. [Qué es Keel](01-que-es-keel.md)
2. [El front y la navegación](02-front-y-navegacion.md)
3. [Proyectos, sesiones y workflows](03-proyectos-sesiones-y-workflows.md)
4. [Delegación y equipos](04-delegacion-y-equipos.md)
5. [Múltiples proyectos](05-multiples-proyectos.md)
6. [Agentes, skills, reglas y hooks](06-agentes-skills-reglas-hooks.md)
7. [MCPs, integraciones y proveedores](07-mcps-integraciones-y-proveedores.md)
8. [Importación, exportación y paquetes](08-importacion-exportacion-paquetes.md)
9. [Flujos operativos](09-flujos-operativos.md)
10. [Diferencias con otras herramientas](10-diferencias-con-otros.md)

Para el detalle técnico feature por feature, ver [`../features/`](../README.md).
Para cómo se compila y distribuye la app, ver
[`../compilar-y-distribuir.md`](../compilar-y-distribuir.md).
