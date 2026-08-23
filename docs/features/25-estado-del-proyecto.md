# F25 — El estado de un proyecto

## Qué problema resuelve

El roadmap (F23) se leía por MCP, para un agente. Vos no tenías ninguna
pantalla: no existía **un solo cálculo de avance en toda la app**. Para saber
cómo iba un proyecto había que abrir la carpeta y contar `.md` a mano, y para
saber quién estaba en qué, mirar cuatro sesiones una por una.

Y hay una pregunta que ninguna de las dos cosas contesta por separado: *¿qué
tarea del roadmap está trabajando qué agente, y en cuál de mis sesiones?*

## Qué es

La primera de las tres secciones de un proyecto —Estado, Tableros,
Sesiones—, arriba y sin lista debajo: no hay estados, hay uno. Las sesiones
entran y salen; cómo va el proyecto está siempre.

Que se estuviera mirando el estado **se deducía** de que no hubiera sesión
abierta, y mientras el proyecto tuvo dos cosas adentro alcanzó. Con los
tableros dejó de alcanzar: «ninguna sesión abierta» pasó a ser tres
situaciones distintas. Ahora es un lente explícito, uno de seis, y quién lo
guarda está en [F32](32-una-sola-navegacion.md).

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

**El botón abre la sesión Y te lleva.** Antes solo la creaba: quedaba en el
sidebar y vos seguías mirando la misma pantalla de error, sin ninguna señal
de que algo había pasado. Crear no es ir —esa regla vale para lo que arranca
solo, no para lo que apretaste—, así que el que navega es el botón.

Y mientras esa sesión siga abierta, el botón **deja de ofrecer abrir otra**:
pasa a decir *ir a la sesión abierta*, o *está trabajando* si hay un turno en
vuelo. Dos sesiones arreglando la misma carpeta se pisan los archivos, y la
segunda arrancaría con un diagnóstico que la primera está cambiando abajo
suyo. La regla vive en el ViewModel y no en el botón: pedir la sesión dos
veces devuelve la misma. Una que quedó en `failed` **cuenta como abierta** —
ese es el veredicto de «arreglá eso y volvé a cerrar», no una para
descartar.

### El agente tiene que poder chequearlo mientras lo arma

`check_roadmap_format` es una tool del turno, y existe por un error que se vio
en uso: el chequeo vivía SOLO en el cierre, así que quien estaba armando el
formato trabajaba a ciegas. Salieron a buscar un comando `keel` en la
terminal —que no existe, lo desinstalamos— y terminaron leyendo el campo
`referencias_rotas` de `list_roadmap_tasks` como si fuera el chequeo
completo. Es una de las siete cosas que mira, no las otras seis.

Dos correcciones que salieron de ahí:

- La tool devuelve exactamente lo mismo que decide el cierre, así que se
  puede iterar hasta que dé verde en vez de cerrar para ver qué pasa.
- El skill del formato ahora dice, con todas las letras, que no hay ningún
  comando `keel` y que `list_roadmap_tasks` no es el checker.

### Un turno de consulta también recibe el roadmap

Antes no lo recibía, y el efecto era el peor posible: **al auditor —que casi
siempre habla consultado— le aparecía «keel-roadmap desconectado» justo
cuando le pedían verificar el roadmap**, y contestaba lo único honesto que
podía, que no tenía con qué. Ahora lo recibe en modo LECTURA: puede listar y
chequear, no puede tomar ni soltar tareas. Tomar es de quien ejecuta el paso;
un consultado contesta y se va.

El modo sale de la URL (`/roadmap/<proyecto>/<sesión>/<perfil>/consulta`), no
de un argumento: un turno de consulta no tiene cómo decir que es un paso.

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
