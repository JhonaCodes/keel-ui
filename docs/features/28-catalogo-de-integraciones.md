# F28 — El catálogo de integraciones, y poder probarlas

## Qué problema resuelve

Registrar un MCP externo ya se podía (F5). Lo que no se podía era **saber
qué existe** ni **si lo que registraste levanta**.

La pantalla arrancaba diciéndote que no habías registrado nada —información
que ya tenías— y te dejaba con un formulario vacío que pide un comando, unos
argumentos separados por espacios y un textarea de `KEY=VALUE`. Funciona si
ya sabés qué va. No te ayuda si no.

Y del otro lado: un MCP mal configurado no avisa. Te enterás tres turnos
después, cuando el agente "no usó la tool", sin poder distinguir si no quiso
o si nunca la tuvo.

## Tres cosas que no existían

### El catálogo

`lib/src/integrations/mcp_catalog/` — data pura, sin Flutter y sin red.
Catorce integraciones con su configuración exacta, su categoría, qué
credencial pide cada una y el enlace a su documentación oficial.

El glifo son **dos letras sobre un color de la paleta de miembros**, no el
logo del servicio. Un logo habría que bajarlo o empaquetarlo, se
desactualiza cuando la marca cambia, y una app que promete no salir a la red
por su cuenta no debería hacerlo para dibujar un ícono.

**El seed no es la fuente de verdad, y el diseño lo asume.** Los comandos y
las URLs de los servidores de terceros cambian sin avisar y este archivo se
entera cuando alguien lo actualiza. Por eso: enlace a la documentación
visible, todo editable después de instalar, y lo de abajo.

### Pegar la config

Los hooks tenían importador (F22) y los MCP no, así que había que traducir a
mano, campo por campo, el bloque `mcpServers` que publica cualquier servidor
en su README.

Ahora se pega y se registra, con preview antes de escribir nada. Es lo que
vuelve al catálogo robusto a quedarse viejo: si una ficha miente, la de la
documentación gana.

El importador avisa cuando un `env` trae una credencial adentro. Y no mira
solo el nombre de la clave, porque el caso más común no se ve venir:
`DATABASE_URL` no tiene una sola palabra sospechosa y lleva la contraseña de
la base escrita. Se detecta también por la FORMA del valor —una cadena de
conexión con `usuario:clave@`—.

### Probar

`lib/src/integrations/mcp_probe/` hace el mismo apretón de manos que hace el
CLI: `initialize`, `notifications/initialized`, `tools/list`. Lo que devuelve
es lo que el agente va a ver.

| Transporte | Cómo |
|---|---|
| stdio | `Process.start` + el canal de `dart_mcp`, y `kill()` en un `finally` |
| http / sse | JSON-RPC a mano sobre `package:http`, leyendo `Mcp-Session-Id` y respuestas SSE |

`dart_mcp` trae canal de stdio pero no de HTTP. Son tres mensajes y el
protocolo está publicado: escribirlos acá salió más barato que arrastrar otra
dependencia.

El resultado se guarda en **un registro aparte** (`mcpprobe_<id>`) y **no
viaja en el respaldo**. Es estado de esta máquina en este momento, no
configuración: restaurar en otra máquina un "conectó, 42 tools" que nunca se
verificó ahí sería una mentira prolija. Mismo criterio que las tomas de
tareas (F23).

Editar un servidor **borra su probe**: cambió la configuración, así que lo
que contestó la última vez ya no lo describe.

## Un secret adentro de un header

El agujero que quedaba del modelo: un servidor remoto no podía sacar su token
de un secret, porque `headers` viajaba como texto plano. Y los tres remotos
más usados —GitHub, Linear, Sentry— son exactamente eso: una URL y un
`Authorization: Bearer`.

Un valor de header ahora puede referenciar `{{NOMBRE}}` y se resuelve al
armar el turno, adentro del archivo temporal de `--mcp-config`. Es una
plantilla y no un mapa clave→secret porque el secret casi nunca es todo el
valor: `Authorization` necesita `Bearer ` adelante.

**Si falta el secret, el header se omite entero.** Medio resuelto es peor que
ausente: un `Authorization: Bearer ` con nada atrás hace que el servidor
conteste 400 donde el header ausente contestaba un 401 legible.

## El límite honesto: OAuth

Cada turno corre con `--strict-mcp-config`, que le dice al CLI que use
**solo** el archivo que le pasamos e ignore la configuración global del
usuario. Eso es lo que hace que un proyecto no herede los MCP de otro.

El precio: un servidor que autenticaste por fuera con `claude mcp add` **no
se ve desde Keel**. Sacar esa bandera arreglaría un caso y rompería el
aislamiento de todos.

Así que las fichas que piden OAuth lo dicen, y un test lo hace cumplir: una
entrada marcada `oauth` sin nota no compila el suite. La salida, cuando el
servicio la ofrece, es un token de API en el header — y el probe lo confirma
en dos segundos en vez de en tres turnos.

## Keel AI

`list_mcp_catalog` e `install_mcp_integration` existen por una razón
concreta: que cuando le pidas "quiero Linear" no invente el nombre de un
paquete de npm. Lee la ficha, registra la configuración exacta y te dice qué
secret falta crear.

El VALOR del secret nunca pasa por el modelo: la tool deja la referencia
puesta y el badge de "falta la clave" aparece solo.

## Verificación

1. Instalar Linear desde el catálogo → el formulario abre lleno, con la
   credencial explicada y el enlace a su documentación.
2. Crear el secret desde ahí mismo → el nombre viene sugerido.
3. **Probar** → la lista de tools de verdad. Borrar el valor del secret →
   falla y dice cuál falta, sin intentar conectarse.
4. Un servidor OAuth sin token → 401, con qué hacer al respecto escrito.
5. Pegar un `{"mcpServers": {...}}` de tres servidores → los tres
   registrados; los nombres tomados aparecen como reemplazo.
6. Pegar uno con `DATABASE_URL` con clave adentro → lo marca.
7. Asignar la integración a un agente y correr un turno: sus tools llegan.
8. Exportar el respaldo → la integración viaja, su probe no.
