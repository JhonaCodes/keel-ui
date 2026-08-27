# F26 — Requerimientos entre proyectos

## Qué problema resuelve

`aulamas-app` necesita un endpoint que vive en `connect-api`. Hasta ahora el
agente lo escribía en su hilo y ahí moría: no había forma de que ese pedido
llegara al otro proyecto, ni de saber después si alguien lo había resuelto.

La salida fácil sería darle al agente acceso al otro repo. Eso rompe justo la
frontera que hace que esto funcione: las reglas y las bases de saber llegan
solo a los miembros de un proyecto **para que un proyecto no sepa cosas de
otro** (F24). Un agente con dos repos abiertos empieza a razonar sobre los
dos, y las decisiones de uno se filtran al otro sin que nadie lo pida.

## La idea

Un requerimiento es **lo único que cruza**.

```
#aulamas-app          │  la frontera  │          #connect-api
                      │               │
  hilo de la sesión   │               │   hilo de la sesión
  plan de trabajo     │  ┌─────────┐  │   plan de trabajo
  su TASKS/           │  │ REQ-0007│  │   su TASKS/
  su carpeta          │  │ necesita│  │   su carpeta
  reglas y saber      │  │ contexto│  │   reglas y saber
                      │  │ veredicto│ │
       ✗ no cruza ────┼─→│ hilo    │←─┼──── ✗ no cruza
                      │  └─────────┘  │
```

Todo lo que atraviesa pasa por **una sola función**,
`renderRequirementForTurn`. Si algo del contexto de origen se cuela ahí, la
frontera se cae en silencio: no hay error, solo dos proyectos que empiezan a
saber cosas del otro. Es la función a mirar en cualquier cambio futuro.

No se comparte sesión de CLI, ni servidor MCP, ni directorio de trabajo.

## La asimetría que lo sostiene

**Cerrar es del proyecto que lo abrió.** Es el único que sabe si lo que
necesitaba está de verdad. El otro lado puede *pedir* el cierre, con una
justificación clara, y esperar.

Eso no se pide por prompt: se comprueba. El proyecto sale de la URL con la
que se le entregó el servidor MCP al turno, así que **un turno del destino no
tiene cómo decir que es el origen**. La regla vive en el ViewModel y no en el
botón, así que vale igual cuando el que intenta es un agente y no un clic.

En la pantalla se ve donde importa: del lado del origen el botón dice
**«Cerrar»**; del lado del destino, ese mismo lugar dice **«Pedir el cierre»**
y exige texto.

## El ciclo

```
abierto ──> tomado ──> en curso ──> respondido ──> cerrado
   │           └────────────────────────┘  (ya resuelto)
   │                        ↑
   │                        └── el origen rechaza y explica
   └──> externo   (el destino está marcado 🔒: lo resolvés vos)
```

El veredicto del destino tiene cuatro formas, y la cuarta es la que un ticket
no sabe contar: **ya resuelto, de otra forma**. El trabajo existe, pero con
otra forma que la que se pidió —`GET /v2/offers?institution_id=` en vez del
endpoint que pedían— y eso no es ni un "sí" ni un "no".

`bloqueado` obliga a nombrar qué va primero. Un bloqueado sin eso no le sirve
a nadie: quien pide no puede ni estimar cuándo volver a preguntar.

## Vos, en el medio

El hilo se lee **como markdown**: lo escriben agentes, y sus encabezados,
listas y negritas son parte de lo que quisieron decir. La barra de color de
cada franja es un **borde** y no una columna al lado — con `Row` +
`CrossAxisAlignment.stretch` la barrita pedía el alto de una franja que vive
en un scroll, o sea sin alto, y eso tiraba «RenderBox was not laid out» en
cada franja y en cada frame: con el volcado del árbol de render entero cada
vez, la ventana se quedaba sin responder hasta matarla a mano.

Tu entrada en el hilo **la ven los dos lados**, y es la única que no escribe
un agente. Es el *"no, mirá, esto se hace así"* cuando los dos están
mirándose de reojo con la razón a medias.

## Llamar a un lado a hablar

Durante un tiempo el hilo fue un documento: escribías «¿esto aplica?» y no
pasaba nada, porque nadie lo estaba leyendo. Para que alguien contestara había
que apretar «Tomar y evaluar», que no es contestar — es abrir una sesión de
trabajo entera para una pregunta de dos líneas.

Faltaba el escalón del medio. Ahora **el `@` trae a un lado a hablar**: lista
a los miembros de los dos proyectos, nombrás a uno, y contesta ahí mismo. El
destino dice si aplica; el origen aclara qué quiso decir. Los dos, en el mismo
hilo, sin abrir nada.

Sin mención no corre nada. Escribir sigue siendo escribir: una nota que ven
los dos, sin gastar un turno en algo que anotaste para vos.

**Ese turno solo lee.** Corre sin sesión —igual que `ask_project`, y por la
misma razón: una sesión es donde se trabaja, y todavía no se decidió
trabajar— parado en el repo de quien contesta, sin un solo servidor MCP
enchufado. Eso último no es una promesa del prompt: sin las tools del
requerimiento, ese turno **no puede** tomarlo, dictaminarlo ni convertirlo
aunque quiera. Lee su código y su roadmap, y contesta.

Lo que cruza sigue siendo lo mismo de siempre: `renderRequirementForTurn`, con
el hilo adentro. Un agente consultado ve el pedido y la conversación; no ve la
sesión del otro, ni su plan, ni su carpeta.

## En qué termina

Un requerimiento aceptado moría en un veredicto de texto: quedaba dicho que sí
y no quedaba **dónde**. `convert_to_task` lo cierra: el destino elige en qué
grupo de su roadmap va y con qué prioridad, y Keel escribe el `.md`.

Lo escribe Keel y no el agente, y es la única tarea del roadmap que no sale de
un file tool. Tres cosas que un programa hace bien y un agente hace mal: el
número —el siguiente libre de la carpeta, sin pisar ni dejar huecos—, el
nombre —un slug sin acentos ni espacios— y el formato exacto que el lector
espera. Lo que sí es del agente es el juicio: **en qué grupo va**. Si el grupo
no existe, la tool falla y lo dice; crearlo sería crear un grupo sin
`README.md`, que rompe el chequeo de formato en el mismo movimiento.

El requerimiento guarda en qué tarea terminó, y el hilo lo muestra. De un lado
del muro queda una conversación cerrada; del otro, trabajo en la fila.

## Trabajan en paralelo, no se contestan

Tomar un requerimiento abre una sesión **nueva** en el proyecto destino,
titulada con su código, cuyo pedido inicial es el bloque renderizado más la
instrucción de evaluar **contra su propio roadmap antes de construir nada**.

Que sea una sesión nueva no es estilo: es la única forma de que el trabajo
del destino no arrastre nada del contexto de quien pidió.

Y corre sola. El origen sigue con lo suyo y se entera cuando hay respuesta.

**«Tomar y evaluar» te lleva a esa sesión.** Es un botón que apretaste: la
regla de que crear no es ir vale para lo que arranca solo —una tool, la
API—, no para esto. Quedarte mirando el requerimiento después de apretar es
quedarte mirando el lado que ya leíste, mientras el trabajo empieza en otra
pantalla.

Una vez tomado, el botón se va y en su lugar queda **«Ir a la sesión»**, que
es la única puerta de vuelta al trabajo que el requerimiento arrancó. Solo
aparece si esa sesión todavía existe: un id guardado no garantiza que lo que
apunta siga estando.

## La compuerta

Un agente **no puede** abrir un requerimiento contra un repo que no esté
registrado como proyecto. La tool falla con un mensaje que dice qué hacer, y
el agente entonces *lo expresa* en su respuesta:

> Falta un endpoint de ofertas por institución, pero **no hay proyecto
> registrado para `connect-api`**, así que no abrí ningún requerimiento.
> Registralo y lo abro; si no, hay que resolverlo por afuera.

Cuando después registrás el proyecto y le decís "acá está", vuelve a intentar
y funciona. Es la diferencia entre un agente que avisa y uno que inventa un
destinatario que no existe.

Si el destino existe pero está marcado como no mantenido (F24), el
requerimiento **sí se crea**, con estado `externo`: queda anotado y a la
vista, y no lo toma nadie. Perder el pedido no ayuda a nadie.

## Preguntar no es pedir

`ask_project` es otra cosa, y por eso es otra tool: le pregunta algo a otro
proyecto —cómo es un endpoint, si algo existe— sin pedirle trabajo. Corre un
agente aparte en ese repo, en lectura, y devuelve **solo su respuesta**.

**Cruza la respuesta, no el acceso.** Quien pregunta nunca recibe esa
carpeta. Es la diferencia entre preguntar y mudarse.

## Las tools

| Tool | Quién | Qué hace |
|---|---|---|
| `list_requirements` | los dos | Los suyos, en las dos direcciones |
| `create_requirement` | origen | Abre uno. Falla sin proyecto registrado |
| `take_requirement` | destino | Lo toma para evaluarlo |
| `record_verdict` | destino | Deja el dictamen, antes de construir |
| `reply_requirement` | los dos | Escribe en el hilo compartido |
| `request_closure` | destino | PIDE el cierre, con justificación |
| `close_requirement` | **solo origen** | Lo cierra |
| `convert_to_task` | destino | Lo convierte en una tarea de SU roadmap |
| `ask_project` | cualquiera | Pregunta sin pedir trabajo |

## Qué pasa si borrás un proyecto

Sus requerimientos **no se borran**: son historia compartida y el otro lado
sigue teniendo derecho a verla. Quedan marcados y sin poder tomarse.

## En el respaldo

Entran, porque son una decisión y no ruido de una sesión. Viajan por código
(`REQ-0007`) y con los proyectos por nombre; los ids y las sesiones son de
esta máquina y no salen.

Al restaurar se **crean si faltan y no se pisan si están**. Un requerimiento
es una conversación viva: restaurarle encima la foto del respaldo borraría
todo lo que se dijo desde entonces, que es exactamente lo que uno no quiere
de un respaldo.

## Verificación

1. Pedir a un destino no registrado: no se crea nada y el agente lo dice.
   Registrar el proyecto, reintentar, se crea.
2. El destino toma, evalúa contra su roadmap y deja `bloqueado` nombrando
   qué va primero. El origen lo ve; su hilo nunca apareció del otro lado.
3. El destino pide el cierre con justificación; `close_requirement` desde el
   destino se rechaza nombrando quién puede.
4. Escribir una corrección en el medio: la ven los dos.
5. Un proyecto 🔒 recibe uno: nace `externo` y nadie lo toma.
6. `ask_project` contesta sobre el otro repo sin que el que pregunta reciba
   acceso a esa carpeta.
7. Respaldar y restaurar en limpio devuelve los requerimientos con su hilo;
   restaurar sobre uno que siguió conversando no lo pisa.
8. `@` en el hilo lista a los miembros de los dos proyectos y a nadie más;
   nombrar a uno del destino lo hace contestar de su lado, y a uno del origen
   del suyo. Escribir sin nombrar a nadie no corre ningún turno.
9. El destino convierte: aparece el `.md` en su `TASKS/` con su `prioridad:`,
   `check_roadmap_format` sigue pasando, y el hilo muestra en qué terminó.
   Convertir dos veces se rechaza.
