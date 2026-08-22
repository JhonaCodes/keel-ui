# F24 — Una estación es un proyecto, y su tarea es una sesión

## Qué problema resuelve

Dos, y el segundo es el que dolía.

El primero es que el nombre mentía desde el principio. El comentario del
propio modelo decía *"El contexto de un PROYECTO"*, su carpeta de trabajo ya
era la identidad con la que el roadmap separa un repo de otro, y sus reglas
existían para que *"un proyecto no sepa cosas de otro"*. Todo el vocabulario
alrededor decía proyecto; solo la clase decía estación.

El segundo es una colisión real. **"Tarea" significaba dos cosas a la vez**:
el hilo del canal (`StationTask`) y la tarea del roadmap en `TASKS/`. Mientras
fueron dos pantallas distintas se podía convivir; el estado del proyecto (F25)
las pone a las dos en la misma tabla, y ahí ya no.

```
antes                          ahora
Estación  ──> Tarea            Proyecto ──> Sesión
             (hilo del canal)               (hilo del canal)
   TASKS/ ──> tarea               TASKS/ ──> tarea
             (del roadmap)                   (del roadmap)
```

## Qué cambió

Todo: símbolos, textos, nombres de archivo, claves de la base, la categoría
del respaldo y las rutas de la API local. Renombrar a medias —la pantalla en
un idioma y el código en otro— es exactamente lo que ya pasaba.

Un caso vale por el resto: `StationTask.sessionsByProfileId` guardaba las
sesiones **del CLI**. Con la tarea llamándose sesión, esa línea decía sesión
dos veces y ninguna de las dos era la misma. Ahora es
`cliSessionsByProfileId`, y "sesión" significa una sola cosa.

## Lo que se guardó en disco

Es la única parte que podía perder datos, así que es la única con prueba.

| Antes | Después |
|---|---|
| `station_<id>` | `project_<id>` |
| `task_<estación>_<tarea>` | `session_<proyecto>_<sesión>` |
| `msg_<sesión>_<n>` | igual — lleva el id de la sesión, que no cambió |
| categoría `stations` del respaldo | `projects` |
| `POST /stations/<n>/tasks` | `POST /projects/<n>/sessions` |

`migrateStationsToProjects()` **escribe, verifica y recién ahí borra**.
Escribir es idempotente porque los ids no cambian: una corrida cortada a la
mitad no duplica nada, la segunda escribe lo mismo encima. Y la bandera se
pone al final: mientras no esté, los registros viejos siguen enteros y la
migración se reintenta sola en el próximo arranque. Esa es la vuelta atrás.

Adentro del payload solo se mueven dos nombres de campo (`taskIds` y
`activeTaskId`). Cuanto menos transforme una migración, menos puede romper.

**Los formatos que miran hacia afuera siguen respondiendo.** Un `.zip` del
respaldo hecho antes del cambio importa igual, porque `stations` se sigue
LEYENDO como alias de `projects` (escribir, escribe siempre el nombre nuevo).
Y `/stations/<n>/tasks` sigue contestando: afuera puede haber un cron escrito
hace meses que no tiene por qué enterarse de que acá adentro cambiamos las
palabras.

## Renombrar un proyecto donde está

Doble click sobre el nombre y el texto se convierte en un campo. El patrón ya
existía y funcionaba —lo usaban las sesiones— pero vivía escrito adentro de
la fila; ahora es `InlineRenameField` y lo usan las dos.

Lo que aporta de nuevo: **un nombre inválido no cierra la edición**. El error
aparece debajo y el cursor se queda donde hay que corregir. Cerrar el campo y
volver a abrirlo para arreglar un guion de más es la clase de fricción que
hace que la gente no renombre nada.

Renombrar es seguro por construcción: nada apunta a un proyecto por nombre
salvo la ruta de la API local y las tomas del roadmap, que vencen solas a los
30 minutos.

## Borrarlo, escribiendo el nombre

El resto de los borrados de la app se confirman con un botón, y está bien:
una regla se vuelve a escribir. Un proyecto no — se lleva sus sesiones, sus
hilos y el contexto que los agentes acumularon.

El diálogo enumera qué se va **antes** de llevárselo (N sesiones, M mensajes,
las tomas que se liberan, los requerimientos que quedan marcados) y contesta
la pregunta que todo el mundo tiene en la cabeza: **la carpeta del repo no se
toca**. El botón queda apagado hasta que el texto coincida exacto.

Escribir el nombre no es una traba: es el segundo de pausa que hace falta
para leer esa lista.

## Cuando el proyecto no es tuyo

`Project.maintained`. En falso, el proyecto es de **solo lectura**, y eso se
hace de la única forma que funciona: **sacándole las tools que escriben**.

Pedírselo por prompt sería pedir. Una tool que no está en el turno no se
puede usar aunque el modelo quiera, aunque se lo pidan, y aunque se le
ocurra. Las tools propias del usuario sí siguen: son suyas, y marcar el
proyecto como ajeno no dice nada sobre ellas.

Además, un proyecto así no toma requerimientos entrantes (F26): quedan
anotados como externos, para que los resuelvas vos.

## Verificación

1. Migrar con datos reales: proyectos, sesiones y mensajes aparecen iguales.
2. Cortar la app a mitad de la migración y reabrir: termina, sin duplicar.
3. Un `.zip` del respaldo hecho antes del cambio sigue importando.
4. `POST /stations/<n>/tasks` y `GET /tasks/<id>` siguen contestando.
5. Doble click renombra; un nombre inválido muestra el error sin cerrar.
6. Borrar exige el nombre exacto, enumera lo que se lleva, y la carpeta del
   repo sigue ahí.
7. Un proyecto marcado como no mantenido corre una sesión y el turno no
   recibe Bash, Edit ni Write.
