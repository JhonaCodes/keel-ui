# F30 — Máquina: servicios, consumo y fierro

## Qué problema resuelve

Tres preguntas que hasta ahora se contestaban afuera de la app: qué CLIs
tengo instalados (una terminal), cuánto llevo consumido (un dashboard web), y
por qué la máquina está lenta (el Monitor de Actividad).

Las tres son sobre lo mismo —lo que Keel está haciendo en esta máquina— así
que van juntas.

## Lo primero: dejar de tirar los tokens

El CLI informa los contadores de cada turno en su evento `result`. La app los
leía, los sumaba para el porcentaje de contexto y **los descartaba**. Es un
termómetro del momento; nunca fue una serie.

Por eso hay que decirlo donde se lee: **el historial empieza el día que esto
se instala**. Ningún gráfico puede mostrar lo de antes, y un vacío sin
explicación parece un bug.

`lib/src/integrations/usage_ledger/` guarda un registro por turno —cuándo,
motor, modelo, perfil, proyecto, sesión, los cuatro contadores, duración y
costo— y lo poda a noventa días. Es **append-only**: escribe una clave por
turno en vez de reescribir la lista entera, que es lo que haría
`replaceAllWithPrefix` en cada mensaje.

### Codex se anota igual, en cero

Su CLI no informa nada (`codex_cli_service.dart` fija costo y duración en 0 y
no emite contexto). Eso **no es lo mismo** que no haber gastado.

Sin la fila, la pantalla diría que codex no corrió. Con la fila en cero,
diría que salió gratis. Se anota, y el rollup lo marca como *sin medición*.

### Una duplicación que se fue

La lectura del evento `result` estaba escrita palabra por palabra en dos
lados: `ClaudeCliService` y el isolate del task runner, que arma mapas en vez
de objetos porque tienen que cruzar la frontera del isolate.

Lo que compartían no era la forma sino la LECTURA. Eso quedó en
`core/services/turn_usage.dart`, puro y con pruebas, y las dos lo usan.

Ahí también quedó escrito algo que valía la pena: el contexto ocupado es
entrada + caché, **sin la salida**, porque lo que llena la ventana es lo que
entra, y lo generado ya está contado adentro del input del turno siguiente.

## Qué hay instalado

`which` + `--version` sobre una lista conocida, en paralelo, cacheado diez
minutos: un CLI no se instala mientras mirás la pantalla.

Claude y codex van marcados como **soportados**. Cualquier otro que aparezca
—opencode, gemini, cursor-agent, amp, aider, ollama— se lista como
**detectado, sin adaptador**. Es más honesto que hacer de cuenta que no
existen, y de paso esa lista es la de lo que falta.

Detectar no es integrar: ninguno de esos entra a correr un turno.

## El fierro

`sysctl` para el chip, los núcleos y la carga; `vm_stat` para la memoria;
`ps` para los procesos.

La memoria ocupada **no** es "total menos libre". En macOS lo inactivo y el
caché de archivos se devuelven cuando hacen falta, así que contarlos daría
95% siempre y no diría nada. Lo que ocupa de verdad es activo + wired +
comprimido, que es lo mismo que muestra el Monitor de Actividad.

Se muestrea cada 3 segundos **solo con la pantalla abierta**. Un timer
corriendo siempre para dibujar un número que nadie está mirando es
exactamente el tipo de cosa que hacía que la app tardara veinte segundos en
dejarse tocar (F27).

### De parte de quién corre cada proceso

`ps` sabe el pid y el comando pero no el motivo, y el motivo es lo único que
hace útil la lista: "claude al 78% de CPU" no dice nada; "claude al 78%, por
la sesión del bid que llega en cero", sí.

`RunningProcesses` es una tabla de pid → etiqueta que se llena al arrancar
cada turno y se limpia al terminarlo. Los turnos de proyecto corren en otro
isolate, así que su pid llega **como número por mensaje**: un `Process` no
cruza la frontera de un isolate, y del otro lado solo hace falta el número.

## El gráfico

Un `CustomPainter` propio y no un paquete de charts. El repo ya dibuja a mano
(`SessionGraphPainter`), son catorce barras, y una dependencia de gráficos
para esto traería cien widgets que nadie más va a usar.

Los días sin actividad se dibujan igual, como una línea al ras: un hueco en
el eje dice algo, y saltearlo mentiría sobre el ritmo. El color de cada
modelo sale de su nombre y no de su posición, así que si un día no usaste
opus el resto no cambia de color.

## Lo que esta pantalla no puede decir

**El consumo es el de Keel, no el de tu cuenta.** La app solo puede sumar lo
que salió por acá; lo que gastaste en una terminal aparte no lo ve, y
prometer lo contrario sería inventar un número.

**El fierro es de macOS.** `sysctl` y `vm_stat` no existen en otro lado. Como
la app hoy es solo de macOS no es una limitación todavía, pero es una deuda
escrita.

## Verificación

1. Abrir Máquina: claude y codex detectados, con versión y ruta.
2. Un CLI instalado que Keel no soporta aparece como *detectado, sin
   adaptador*; uno que no está, como *no instalado*.
3. Correr un turno y volver: ese día suma en el gráfico.
4. Un turno de codex aparece en la tabla como *sin medición*, nunca en cero.
5. Con un turno corriendo, su proceso está en la lista con de parte de quién.
   Al terminar, desaparece.
6. Cerrar la pantalla: el muestreo se detiene.
7. Con el ledger vacío, la pantalla explica por qué en vez de mostrar un
   gráfico en blanco.
