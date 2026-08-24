# 10 — Diferencias con otros herramientas

## Eje de comparación

Hay tres categorías de herramientas que lo **parecido a Keel** pero manejan múltiples agentes y proyectos de formas distintas. La comparación acá no es "cuál es mejor" — es dónde está el trade-off de diseño en cada una.

## Cuadro comparativo

| Dimensión | Claude Code | Cursor | Windsurf | Codex CLI | Keel |
|---|---|---|---|---|---|
| **Terminal puro** | No | No | No | Sí | No |
| **Agentes registrados** | 1 por sesión | 1 por sesión | 1 por sesión | 1 suelto | 1+ reutilizable |
| **Rol-based workflows** | No | No | No | No | Sí |
| **Múltiples proyectos** | Sí, pestaña por pestaña | Sí, multi-workspace | Sí, multi-workspace | No | Sí, aislado |
| **Comunicación inter-proyecto** | Chat en la misma ventana | No definido | No definido | No | REQs formales |
| **Exportar configuración** | No | No | No | `.cursor-config.yml` | Vault + paquetes |
| **MCP integrado** | Sí, local | Sí, local | Sí, local | No | Sí, local + externo |
| **Múltiples proveedores** | No (solo Claude) | No (solo OpenAI) | No (solo OpenAI) | `codex` solo | claude + codex |
| **Local-first** | Sí | No (OpenAI API) | No (OpenAI API) | Sí | Sí |
| **UI desktop** | No | Sí, editor | Sí, editor | No | Sí |
| **Dónde corre** | Web + ext. VSCode | Editor (local binaries) | Editor (local binaries) | Terminal | macOS desktop app |

## Qué Keel **no es**

### No es un editor

Keel no reemplaza a Cursor ni a Windsurf — no es un IDE. Tu editor favorito sigue siendo el editor. Keel **orquesta agentes** que usan sus propias herramientas (archivo, git, etc.) en lugar de editores visuales.

### No es Claude Code en multi-proyecto

Claude Code vive en web y maneja un proyecto a la vez. Keel **aisla proyectos**: dos sesiones de Keel no comparten contexto, plan ni historial. Claude Code trae el contexto en la URL; Keel lo trae en la base de datos local.

### No reemplaza Codex CLI

Codex CLI es una terminal mejorada. Keel usa Codex CLI **como proveedor**, pero agrega roles, workflows, coordinación entre agentes y proyectos. Si tu flujo es "ejecuto un comando y leo la salida", Codex CLI es más ligero.

## Dónde el valor real es diferente

### Workflows reutilizables

El mismo `tdd` workflow funciona idéntico en Flutter, Rust y Python porque apunta a **roles**, no a nombres específicos. Cursor y Windsurf necesitan que configures cada editor en cada proyecto. Keel lo configura una vez, en el agente, y viaja.

### Proyectos aislados con comunicación explícita

Cursor y Windsurf son "múltiples ventanas del mismo cerebro". Keel es "varios cerebros en la misma máquina, comunicando cuando necesitan". Es más cercano a cómo trabaja una empresa: equipos separados (core, billing, auth) que se consultan por requerimientos formales, no que leen lo que hizo el otro en el hilo de Slack.

### Secretos y orquestación segura

Cursor y Windsurf usan env vars. Keel trata los secretos como configuración de primera clase — cargados desde la UI, nunca visibles en prompts o logs, resueltos en proceso aislado. Eso lo hace más seguro en máquinas compartidas.

### Portabilidad de configuración

Si exportas una skill de Keel, alguien la puede instalar en su máquina y funciona. Si exportas una configuración de Cursor, hay rutas hardcodeadas y modelos que vos tienes acceso y la otra persona no. Keel maneja eso.

### Determinismo garantizado

Cursor y Windsurf son "proporciona prompts, la IA decide qué hace". Keel agrega:
- **Skills estáticas** — el agente no decide qué sabe, eso está escrito.
- **Hooks** — comandos deterministas que se ejecutan sin que el modelo lo decida.
- **Scope por URL** — un agente no puede acceder a proyectos ajenos porque la ruta no existe para él.

Eso es lo que lo hace escalar — en una equipo de 20 agentes, necesitás garantías, no confiar en prompts.

## Siguiente paso

Ya terminaste de leer la **documentación de producto**. Si necesitas detalles técnicos específicos — cómo están estructuradas las features, qué cambios vinieron en cada release — leé [`../features/`](../README.md).

Para entender cómo se compila y distribuye Keel, leé [`../compilar-y-distribuir.md`](../compilar-y-distribuir.md).
