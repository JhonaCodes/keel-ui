# F4 — Secrets ocultos al LLM

## Qué es

Registro de claves/credenciales (`Secret{name, description, value}`) cuyos
VALORES nunca pasan por un modelo:

- La UI siempre los enmascara (`••••`, sin botón de revelar; el formulario
  es write-only: en edición, vacío = conservar el valor actual).
- Se inyectan como variables de entorno SOLO a procesos deterministas:
  scripts de tools (`Tool.secretNames` → `ToolExecutionService.run(
  environment:)`) y, desde F5, servidores MCP externos. JAMÁS al CLI del
  agente (un agente con Bash haría `echo $X` y el valor entraría al modelo).
- El nombre sigue formato de variable de entorno (`^[A-Z][A-Z0-9_]{0,63}$`).

## Flujo "pendiente"

Un agente (Keel AI o constructor) puede PEDIR que exista una clave con
`request_secret(name, why)`: se crea sin valor, marcada **pendiente**, con
quién la pidió. Solo el usuario carga el valor, en la pantalla Secrets
(icono llave en el rail). Una tool cuyos secrets declarados están pendientes
falla CERRADA con mensaje accionable (nunca corre con la variable ausente).
`list_secret_names` lista nombres+estado, nunca valores.

## Anti-leak `ps`

Desde este feature el `--mcp-config` de CADA turno (1:1 y estaciones) se
escribe a un ARCHIVO temporal en un directorio 0700 y se pasa la ruta al
CLI, en vez de JSON inline en argv (visible en `ps`). El directorio se borra
al terminar el turno. Aplica en `ClaudeCliService` y en el isolate del
task_runner.

## Almacenamiento

LMDB local (prefijo `secret_`), mismo storage que el resto del catálogo.
Los secrets NUNCA entran al export de catálogo (F9). `Secret.toString()`
no imprime el valor.
