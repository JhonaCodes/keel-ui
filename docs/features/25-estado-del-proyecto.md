# F25 — El estado de un proyecto

## Qué problema resuelve

El roadmap (F23) se leía por MCP, para un agente. Vos no tenías ninguna
pantalla: no existía **un solo cálculo de avance en toda la app**. Para saber
cómo iba un proyecto había que abrir la carpeta y contar `.md` a mano, y para
saber quién estaba en qué, mirar cuatro sesiones una por una.

Y hay una pregunta que ninguna de las dos cosas contesta por separado: *¿qué
tarea del roadmap está trabajando qué agente, y en cuál de mis sesiones?*

## Qué es

Una sección **fija** de cada proyecto, arriba de sus sesiones, que no se
cierra. Las sesiones entran y salen; cómo va el proyecto está siempre.

No hace falta un campo que diga "estoy mirando el estado": es lo que se ve
cuando no hay ninguna sesión abierta, que es exactamente lo que significa. Un
segundo campo para lo mismo se desincroniza solo.

**Mira, no toca.** No hay un solo control adentro, y es una decisión: para
abrir una sesión está su fila en el sidebar, a diez píxeles. Una pantalla que
informa y además actúa termina siendo dos pantallas malas.

## De dónde salen los números

De cruzar tres cosas que hasta ahora no se cruzaban en ningún lado:

| Qué | Dónde vive | Quién lo escribe |
|---|---|---|
| Las tareas y su estado | El repo, en `TASKS/` | Los agentes, al cerrar |
| Quién tiene cada una | La base local | La toma, atómica |
| Las sesiones vivas | La base local | El turno que corre |

`buildProjectRadar` es una función **pura**: entra data, sale el modelo de la
vista. Es lo único de esta pantalla que se puede probar sin la app entera.

**La toma manda sobre el archivo.** Una tarea con `estado: libre` y alguien
trabajándola cuenta como en curso, porque el `.md` se marca al cerrar el
turno: hasta entonces diría que nadie la está haciendo justo cuando alguien
la está haciendo.

Los borradores se cuentan aparte y **no entran en el total**. Todavía no son
una promesa, y meterlos hunde el porcentaje sin que nadie haya fallado.

## Los cinco bloques

- **Cumplimiento** — `14 de 31 · 45%` y una barra de cuatro segmentos.
- **En curso ahora** — por cada toma viva: la tarea, el agente con su color
  del canal, **en qué sesión corre**, hace cuánto y cuánto le queda a la
  toma. Ordenado por la que vence primero, que es lo único accionable.
- **Sesiones en el radar** — todas, con su paso, su plan, su costo y qué
  tarea del roadmap tienen tomada.
- **Trabado** — bloqueantes abiertos y **referencias rotas**. Es la primera
  vez que eso se ve en pantalla: el lector ya las detectaba, pero solo
  salían en el error de `claim_task`, cuando alguien ya se había chocado.
- **Requerimientos** — dos contadores hacia F26.

## Cuándo se relee

`readRoadmap()` no cachea a propósito (F23) y recorrer un directorio es
barato. Se relee cuando cambia una toma y cuando cierra un turno —los dos
momentos en que los números se mueven de verdad— y cada 15 s como piso, que
existe para lo que pasa AFUERA de la app: un `git pull`, otro agente marcando
`estado: hecho` desde otra máquina.

## Cuando el repo todavía no tiene el formato

Un cero no dice nada: no distingue "todavía no arrancó" de "está mal
escrito", y son dos problemas con dos salidas distintas.

Así que sin formato la pantalla no muestra ceros: muestra **qué falta, línea
por línea**, con el archivo, y ofrece una sola cosa: abrir la sesión que lo
arregla. `checkRoadmapFormat()` chequea siete cosas —la carpeta en la raíz,
su README, los grupos con el suyo, ninguna tarea suelta, los frontmatter,
cero referencias rotas— y devuelve hallazgos concretos, no un booleano.

Esa sesión arranca con el diagnóstico ya adentro del pedido y con un skill
reservado, `keel-formato-de-tareas`, que lleva la especificación entera y las
plantillas inlineadas: el agente no depende de leer nuestro repo.

### El chequeo al cerrar no se puede saltear

Pedirle a un agente que verifique su propio trabajo por prompt es pedir, no
garantizar — la misma distinción que separa una regla de un hook (F22).

Cuando esa sesión cierra, keel-ui corre `checkRoadmapFormat()` **por su
cuenta** y publica el resultado en el hilo, con la lista entera: lo que pasó
y lo que no. Si algo falla, **la sesión no queda terminada** y lo que falló
es el pedido siguiente.

Vive en `_finishSession`, que es el único lugar por donde pasan TODOS los
cierres. Una verificación que se puede esquivar por otra rama no es una
verificación.

Y no hay nada que "importar" después: el lector lee la carpeta fresca cada
vez, así que en cuanto el chequeo pasa, el estado empieza a funcionar solo.

## Verificación

1. Un repo con `TASKS/`: el porcentaje coincide con contar los `.md` a mano.
2. Una tarea tomada aparece con su agente **y su sesión**.
3. Una tarea con `estado: libre` y toma viva cuenta como en curso.
4. Una referencia rota aparece en "Trabado" con el archivo y el motivo.
5. Sin formato, la pantalla dice qué falta y no muestra ceros.
6. «Definir el formato» abre la sesión con el diagnóstico en el pedido.
7. Esa sesión cierra con una referencia rota → NO queda terminada, y el
   hilo trae la lista.
8. Arreglarla y volver a cerrar → terminada, y el estado ya está leyendo.
