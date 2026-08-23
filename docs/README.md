# La documentación de Keel

Cada archivo de `features/` cuenta **una** cosa: qué problema resuelve, cómo
está resuelta, y qué decisiones se tomaron en el camino que no se ven en el
código. Están numerados por orden de aparición, no de importancia.

Si venís de afuera, el [README](../README.md) tiene el modelo mental
completo; esto es el detalle.

## Los cimientos

| | |
|---|---|
| [F0](features/00-fundacion-multi-ventana.md) | Fundación multi-ventana |
| [F1](features/01-ventana-asistente.md) | La ventana de Keel AI |
| [F2](features/02-keelai-compilado-y-constructores.md) | Keel AI compilado + agentes constructores |
| [F15](features/15-keelai-ojos-abiertos.md) | Keel AI con los ojos abiertos |

## Lo que un agente lleva puesto

| | |
|---|---|
| [F3](features/03-skills-globales.md) | Skills globales |
| [F4](features/04-secrets.md) | Secrets ocultos al LLM |
| [F5](features/05-mcps-externos.md) | Integraciones MCP externas — el mecanismo |
| [F28](features/28-catalogo-de-integraciones.md) | El catálogo, y poder probarlas |
| [F16](features/16-bases-de-saber.md) | Bases de saber |
| [F22](features/22-hooks.md) | Hooks: guardarraíles que corren solos |
| [F6](features/06-proveedor-codex.md) | Proveedor codex por agente |
| [F18](features/18-motor-por-proyecto.md) | Motor de un miembro por proyecto |

## Trabajar

| | |
|---|---|
| [F24](features/24-proyectos-y-sesiones.md) | Un proyecto, y sus sesiones |
| [F17](features/17-plan-de-sesion.md) | El plan de trabajo de una sesión |
| [F23](features/23-roadmap-de-tareas.md) | El roadmap de un proyecto |
| [F25](features/25-estado-del-proyecto.md) | El estado de un proyecto |
| [F26](features/26-requerimientos-internos.md) | Requerimientos entre proyectos |
| [F8](features/08-agente-por-sesion.md) | Agente temporal por sesión |
| [F29](features/29-tableros.md) | Tableros de prueba |
| [F32](features/32-una-sola-navegacion.md) | Una sola navegación |
| [F34](features/34-worktrees.md) | Trabajar en otro worktree, y volver |
| [F37](features/37-un-workflow-por-sesion.md) | Un workflow por sesión |

## La conversación

| | |
|---|---|
| [F13](features/13-imagenes-en-el-chat.md) | Imágenes en el chat |
| [F14](features/14-cola-de-mensajes.md) | Escribir mientras el agente trabaja |
| [F19](features/19-enlaces-y-pr.md) | Enlaces clickeables y el PR de la sesión |
| [F7](features/07-comunicacion-economica.md) | Comunicación económica + el ledger |
| [F10](features/10-sugerencias-skills.md) | Sugerencias de skills recurrentes |
| [F11](features/11-conocimiento.md) | La sección Conocimiento |

## La máquina

| | |
|---|---|
| [F20](features/20-respaldo-en-un-archivo.md) | Respaldo en un archivo |
| [F21](features/21-vault-del-sistema.md) | El vault del sistema |
| [F33](features/33-paquetes.md) | Paquetes: compartir un agente entero |
| [F12](features/12-jobs-api.md) | API local de trabajos programados |
| [F27](features/27-arranque-y-espera.md) | El arranque, y decir que estás esperando |
| [F30](features/30-maquina.md) | Servicios, consumo y fierro |
| [F31](features/31-mapa-de-razonamiento.md) | El mapa: ver cómo se piensa |
| [F35](features/35-diario-de-fallas.md) | El diario de fallas |
| [F36](features/36-actualizar-keel.md) | Qué Keel estás corriendo, y actualizarlo |

## Lo demás

- **`mockup/`** — los dibujos que se aprobaron antes de escribir Dart:
  [proyectos y requerimientos](mockup/proyectos-y-requerimientos.html),
  [integraciones, tableros y máquina](mockup/integraciones-tableros-y-maquina.html)
  y [el mapa de razonamiento](mockup/mapa-de-razonamiento.html).
  Están hechos con los tokens exactos de `app_theme.dart`, así que sirven
  como referencia de lo que la UI tiene que parecer.
- **`plantillas/TASKS/`** — el esqueleto de un roadmap de proyecto (F23),
  para copiar dentro de un repo.

> No hay F9. Se numeró y no se escribió, y renumerar veinte archivos para
> tapar un hueco cuesta más de lo que vale.
