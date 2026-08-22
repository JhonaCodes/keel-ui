# F27 — El arranque, y decir que estás esperando

## Qué problema resuelve

Abrir keel-ui y no poder hacer click durante veinte segundos. La ventana ya
estaba ahí, con contenido, y no contestaba.

La lectura obvia —"está cargando, falta un indicador"— era la equivocada, y
vale la pena decir por qué: **ya había un indicador**. `VaultBootGate`
mostraba un `CircularProgressIndicator` durante exactamente ese intervalo.
Lo que pasaba es que no giraba. El hilo de la UI no estaba ocupado: estaba
**bloqueado**, y un spinner necesita frames para girar.

De ahí sale el orden de este trabajo: primero destrabar el hilo, después
poner la barra. Una barra sobre un hilo bloqueado se congela igual.

## Lo que estaba bloqueando

### La base se leía entera, una y otra vez

`flutter_local_db` no tiene consulta por prefijo. Solo sabe devolver **una**
clave (`GetById`) o **toda** la base (`GetAll`). Así que
`LocalDatabase.getAllWithPrefix` traía todo y filtraba en Dart.

Y `GetAll` no es una lectura: serializa la base entera a JSON, la cruza por
FFI, la decodifica, y después **re-serializa y re-parsea registro por
registro** — más otro `jsonEncode` por registro para calcular su hash. Son
tres a cinco pasadas de serialización sobre toda la base **por llamada**. La
firma es `async` pero el cuerpo no tiene un solo `await`: no cede el hilo
nunca.

Con la base en 5,5 MB, el arranque hacía **once más una por sesión**: dos del
seed de Keel AI, siete de los catálogos, una de proyectos, una de agentes, y
**una por cada sesión** para juntar sus mensajes. Cada una deserializaba
todos los mensajes de todas las sesiones para descartar el 99%.

No era solo el arranque. `ProjectsRepository.save()` hacía
`1 + proyectos + sesiones` de esas lecturas y se llama desde cuarenta lugares
del ViewModel; `PromptInsights.record()` hacía otra en cada mensaje que
mandabas. Era el tirón que se sentía trabajando.

### El índice del saber se armaba antes del primer frame

`KnowledgeViewModel` no resolvía su `ready` hasta terminar de indexar, y
indexar recorre el disco de cada base con `listSync` recursivo más un
`readAsStringSync` por portada. Con doce bases registradas eran unas 6.700
entradas — una sola carpeta tenía 4.608.

Y el tope de 5.000 archivos no cortaba la recursión de directorios: el corte
por presupuesto estaba solo en la rama de archivos, así que un árbol grande
se recorría entero aunque ya no hubiera nada que indexar.

Como `KnowledgeService.ready` entraba en `awaitCatalogsReady()`, ese
recorrido pasaba completo antes de que la app dejara ver nada.

## Qué se hizo

### La base se lee una vez y queda en memoria

Un índice por clave dentro de `LocalDatabase`, que ya era —y lo decía su
propio comentario— el único archivo del proyecto que importa
`flutter_local_db`. Las consultas por prefijo filtran ese mapa: cero FFI,
cero JSON.

Tres decisiones que sostienen que no se desincronice:

- Las escrituras actualizan el índice **después** de que la base confirmó.
  Una escritura que falla no puede dejar el índice diciendo que salió bien.
- Las escrituras que caen **mientras el índice se está cargando** se guardan
  aparte y se aplican encima cuando llega. La rendija es angosta pero existe.
- Todo entra y sale **copiado**. Antes cada lectura devolvía objetos recién
  parseados del JSON, así que nadie podía pisarle el registro guardado a
  otro; devolver la referencia del índice habría cambiado esa regla en
  silencio, y un `record['x'] = y` en cualquier repositorio corrompería la
  base en memoria sin un solo error.

Que la copia quede vieja no es un riesgo real acá: las sub-ventanas ni
siquiera escriben —declaran `markUnavailable()` para eso— y nada fuera de la
app toca ese archivo. No hay quién la haga divergir.

Lo que cuesta es memoria: la base entera queda residente. Si algún día
molesta, la salida es podar los mensajes viejos, no volver a escanear.

### El saber indexa por detrás

`ready` y `indexReady` pasan a ser dos cosas, porque son dos cosas:

| | Resuelve cuando | Lo espera |
|---|---|---|
| `ready` | El catálogo de bases cargó | El arranque, y la UI para dibujar la lista |
| `indexReady` | El índice terminó de armarse | El armado del turno de un agente |

El único que necesita el MAPA es el turno: sin él, el agente no ve qué hay
adentro de sus bases. Ahí sí tiene sentido esperar el disco. Para dibujar
una lista de nombres, no.

## La barra, y qué significa

Una franja de 2px pegada arriba y la pantalla atenuada, montadas en el
`builder` del `MaterialApp` — el único lugar que cubre la app entera,
incluidos los paneles laterales, que son rutas del mismo Navigator.

- **Atenuar en vez de tapar**: se ve que la app está ahí y que le falta poco.
  Es distinto de una pantalla de carga, y es información.
- **Sin ocupar layout**: aparece y desaparece sin mover un píxel de lo que
  hay debajo. Es el mismo `SizedBox(height: 2)` que ya usan el chat y el
  canal.
- **`AbsorbPointer`**, y no es decorativo: los clicks que hacías durante el
  arranque se encolaban y se disparaban todos juntos al destrabarse,
  abriendo paneles que nadie pidió.

El estado es un **contador**, no un booleano: dos tareas largas pueden
solaparse y la que termine primero no puede apagar el aviso de la otra.
`during(label, work)` es el único punto de entrada, con `finally`, para que
una tarea que explota no deje la app oscurecida para siempre.

Lo prenden el arranque, respaldar, restaurar, traer el vault, importar un
catálogo y actualizar una base de saber.

## `VaultBootGate` dejó de bloquear

Esperaba los once catálogos para decidir si mostrar la bienvenida, y mientras
tanto reemplazaba la pantalla entera por el spinner. Pero la bandera que
necesita —`vaultOnboardingDone`— sale de los ajustes, que es **una clave**.
Con la bandera puesta, que es el caso de siempre, contesta al instante.

Solo si la bienvenida nunca se hizo hace falta saber si hay algo guardado, y
para eso sí hay que esperar a los catálogos: preguntar antes daría "vacío"
siempre, y la bienvenida se le aparecería a alguien que tiene todo.

## Verificación

1. Abrir la app: se ve la UI atenuada, con la barra **animándose de verdad**,
   y se apaga sola.
2. Apretar el rail mientras está oscurecido no abre nada al destrabarse.
3. `put` y leer con `getAllWithPrefix` devuelve lo nuevo; `delete` lo saca;
   `replaceAllWithPrefix` deja exactamente lo que se le pasó.
4. Lo que se lee no puede corromper el índice: mutar el mapa devuelto no
   cambia lo guardado.
5. Un turno que usa una base de saber recibe el mapa completo, aunque se
   dispare apenas abierta la app.
6. Mandar un mensaje en una sesión con historial largo: sin tirón al guardar.
7. Restaurar un respaldo prende la misma barra y la apaga al terminar,
   incluso si falla.
