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
quién la pidió. Solo el usuario carga el valor. Una tool cuyos secrets
declarados están pendientes falla CERRADA con mensaje accionable (nunca
corre con la variable ausente). `list_secret_names` lista nombres+estado,
nunca valores.

## El formulario: nombre + valor, nada más

El nombre ES la variable de entorno, así que el campo lo dice literalmente
("Nombre de la variable de entorno", con `LINEAR_API_KEY` de ejemplo). El
formulario tenía además un campo "Para qué es" que leído en pantalla
parecía un segundo casillero de nombre: pasó que el nombre real terminó
ahí y el secret quedó registrado como `APIKEY`. Ese input ya no existe.
`Secret.description` sigue en el modelo — es donde un agente explica por
qué pidió la clave (`request_secret(why)`) — y se muestra como contexto de
solo lectura ("Para qué se pidió: …"), nunca como campo a llenar.

Un secret que YA tiene valor no muestra un input vacío (que se lee como
"no está guardado"): muestra `Valor cargado ••••••••` con un botón
"Reemplazar" que recién ahí abre el campo. Enmascarado, pero visiblemente
presente.

## Dónde se carga el valor

Hay UN solo formulario de credencial (`SecretFormScreen`) y todas las
superficies rutean a él, así que "tengo la clave pero no sé dónde va" no
tiene lugar donde pasar:

- Pantalla Secrets (icono llave del rail): registro completo.
- `SecretMultiSelect` — la sección "Secrets (env)" de los formularios de
  tool y de MCP: la misma fila que otorga el secret lo **carga** cuando
  está pendiente (botón «Cargar valor»), le **cambia el valor** cuando ya
  tiene, y lo **elimina** (confirmación compartida, `confirmDeleteSecret`);
  al eliminarlo suelta también el permiso en el formulario abierto.

Antes de guardar, el picker avisa qué secrets marcados NO se van a
inyectar: los **pendientes** (falta el valor) y los **faltantes** (permiso
colgado de un secret eliminado, con acción para soltarlo). En la lista de
Integraciones MCP, `PendingSecretsBadge` marca "falta la clave" en el MCP
que declara un secret sin resolver — la diferencia entre registrado y
usable se ve sin abrir el formulario.

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
