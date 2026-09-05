# Base de saber: arquitectura de proveedores LLM

Esta base cubre **un solo dominio**: cómo Keel UI invoca CLIs de terceros (`claude`, `codex`, y los que se agreguen) y, a futuro, APIs HTTP directas de proveedores LLM. `lib/src/integrations/` tiene ~40 subsistemas — la enorme mayoría (boards_mcp, catalog_bundle, system_vault, git_worktree, fault_journal, mcp_catalog, roadmap_mcp, requirements_mcp, app_update, genui, jobs_api, etc.) **no son parte de este dominio**: son integraciones de otras features de la app y se ignoran para este trabajo.

## Dónde mirar

| Carpeta | Rol | Relevancia |
|---|---|---|
| `task_runner/` | **El corazón del dominio.** `task_runner_isolate.dart` es donde hoy vive el `isCodex = spec.provider == 'codex'` que se está reemplazando por el sealed class de proveedores. `task_run_spec.dart` define el `TaskRunSpec` que cruza el isolate boundary (`fromMessage`/`toMessage`). `task_event.dart` define los eventos que hoy salen del proceso CLI. | Leer completo antes de tocar cualquier runner |
| `task_runner/task_runner.dart` | Barrel del módulo — el `part of` que conecta `task_runner_isolate.dart` con el resto | Punto de entrada para ubicar el resto de archivos del módulo |
| `llm/` (carpeta nueva, todavía no existe en el repo) | Acá va la implementación del diseño de [[arquitectura-llm-providers]]: `llm_provider.dart`, `llm_dispatcher.dart`, y una subcarpeta por proveedor (`codex/`, `claude/`, `gemini/`, `qwen/`, `opencode/`, `openai_compatible/`) | Se crea durante la implementación — no existe todavía |
| `hook_delivery/` | Cómo se resuelven y renderizan los hooks/settings que se le pasan a Claude (`--settings`) y Codex (overrides `-c hooks.*`, ver `codex_config_overrides.dart`) | Consultar solo si un runner nuevo necesita entender cómo se arma ese archivo temporal — no es el foco central |
| `machine/src/service_probe.dart` | Detecta si un CLI está instalado y en qué versión — tiene la misma lógica de "buscar binario en PATH" que necesita un runner nuevo | Referencia útil para `verificar-flags-cli` y para cualquier detección de CLI instalado |

## Qué NO está acá

Todo lo demás en `lib/src/integrations/` (persistencia del catálogo, MCPs propios de Keel como `assistant_mcp`/`boards_mcp`/`roadmap_mcp`, backup del sistema, worktrees de git, actualización de la app) pertenece a otros dominios de la app y no se toca como parte de esta migración de proveedores LLM.

Para el diseño completo del sealed class y el dispatcher, ver la skill `arquitectura-llm-providers` (no vive en esta base, vive en el catálogo de skills de Keel).
