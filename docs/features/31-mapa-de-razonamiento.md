# F31 — El mapa: ver cómo se piensa, no quién habló

## Qué problema resuelve

La pestaña **Mapa** dibujaba un carril vertical con arcos a la derecha: quién
le pasó a quién. Correcto, y ya lo decía el hilo. Lo que no se podía ver era
todo lo demás.

- **No se podía navegar.** Un `CustomPaint` dentro de un scroll vertical. Sin
  zoom, sin arrastre, sin encuadre; con seis miembros el lienzo crecía y el
  panel lo recortaba.
- **El nodo no tenía estado.** Un círculo con un nombre. Pensando, ejecutando,
  escribiendo o trabado esperando un permiso se veían igual.
- **Los subagentes no existían.** Cuando un miembro delegaba con `Task`, el
  mapa no dibujaba nada — y peor: el razonamiento del subagente se mezclaba
  con el del padre en el mismo buffer.
- **Preguntar y contestar eran la misma línea**, así que la ida y la vuelta
  eran indistinguibles.

El dibujo aprobado antes de escribir Dart está en
[`docs/mockup/mapa-de-razonamiento.html`](../mockup/mapa-de-razonamiento.html).

## Lo que lo destrabó: una bandera

El CLI ya sabía hacer lo que faltaba. `--forward-subagent-text` reenvía el
texto **y el pensamiento** de cada subagente como mensajes propios con
`parent_tool_use_id`. Keel no la pasaba, así que lo de adentro de un `Task`
llegaba mezclado con lo del padre y firmado por alguien que no lo escribió.

Con la bandera, `ClaudeStreamReader` (`core/services/claude_stream_events.dart`)
separa las dos corrientes. Ese lector, además, **es uno solo**: el traductor
del `stream-json` estaba duplicado palabra por palabra entre
`ClaudeCliService` y el isolate del task runner, que es por qué el chat 1:1 y
los proyectos se desincronizaban cada vez que el CLI agregaba algo.

Guarda una sola cosa entre eventos: los `tool_use` de `Task` que vio. Sin ese
recuerdo no hay forma de saber cuál de los cientos de `tool_result` de un
turno es la devolución de un subagente, y habría que mandarlos todos por el
puerto del isolate para descartarlos del otro lado.

## Columnas por paso, no por agente

El workflow `tdd` real tiene ocho pasos y le da **tres seguidos** al mismo
miembro. Un nodo por miembro convertiría esa línea recta en un nudo de
flechas que vuelven sobre sí mismas.

Así que una columna es un **paso**. El mismo `flutter-expert` aparece cuatro
veces porque genuinamente tiene el turno cuatro veces, y una consulta «a un
agente de un paso anterior» tiene un destino que existe.

Sin workflow no hay columnas prestadas: los miembros se acomodan en el orden
en que hablaron, y los que todavía no hablaron van detrás, en reposo.

## Tres carriles fijos

Siempre los mismos y en el mismo lugar, así que una línea que sube significa
lo mismo en cualquier sesión sin mirar la leyenda:

| Carril | Qué vive ahí |
|---|---|
| **vuelve** (arriba) | consultas entre nodos y quién registró a quién |
| **avanza** (medio) | la fila de pasos, de vos hasta el fin |
| **delega** (abajo) | los subagentes, colgados del paso que los abrió |

## Diez líneas, diez eventos

El grosor dice importancia, el color dice familia, y el patrón dice dirección
del favor: **trazo continuo avanza, guiones largos piden, puntos contestan**.

| Línea | Evento | De dónde sale |
|---|---|---|
| Avance | el paso cambió de dueño | `stepIndex` del mensaje |
| Avance en vuelo | el paquete está viajando | turno abierto sin autor nuevo |
| Consulta | alguien llamó a otro nodo | `consultOfProfileId` |
| Respuesta | el llamado contestó | mensaje del consultado |
| Delegación | se abrió un subagente | `tool_use` · `Task` |
| Devolución | el subagente entregó | `tool_result` del `Task` |
| Lo registró | relación de elenco, nunca se anima | `createdByProfileId` |
| Entrega final | la sesión cerró | `SessionStatus.finished` |
| Cortó | error, hook que bloquea o permiso negado | `is_error` |
| Sin recorrer | el camino existe, nadie pasó | pasos sin dueño |

**Contestar una consulta no hace avanzar el workflow.** Un miembro puede
contestar desde un paso que todavía no le tocó; sin esa distinción la flecha
se encendía hasta él y el mapa mentía sobre dónde va el trabajo. Su cuadro
dice «contestó», no «resolvió».

## El vuelo: transmite, llega, procesa

El error del mapa viejo era que la animación vivía en la línea de punta a
punta. Acá la línea **solo se mueve mientras el paquete viaja**; en cuanto
llega se apaga, y el que empieza a moverse es el nodo. Eso es lo que separa
«se lo está pasando» de «ya lo tiene y lo está pensando».

El motor de la animación corre **solo si hay algo en vuelo**. Un timer que
late siempre es exactamente lo que se arregló en F27.

## Un cuadro por agente, ocho estados

`reposo · pensando · trabajando · escribiendo · contestando · esperándote ·
cerrado · cortó`

Nada se apila, nada crece hacia abajo salvo el cuadro punteado de lo que
resolvió, y lo que ya pasó queda como **número en el pie** —no como otro
cuadro en el lienzo.

Mientras el nodo tiene el turno, el pie muestra los **mismos indicadores
animados que el chat**: `AgentActivityIndicator` con el icono de la
herramienta que gira, y `TurnPhaseLabel` con la línea que respira. No son una
copia parecida —dos animaciones distintas para el mismo estado se leen como
dos estados distintos.

El texto de «resolvió» es **la primera frase de lo que escribió**, no un
resumen generado: pedirle al modelo que se resuma cuesta otro turno y puede
mentir sobre lo que hizo.

## La réplica: un cuadro, tres estados, y después un número

En el lienzo hay **como mucho un cuadro vivo por par de nodos**. Pide → el
cuadro dice qué pidió. Contesta → el mismo cuadro cambia. Cierra →
desaparece y queda el arco tenue con el contador en el pie del nodo.

Diez consultas entre el mismo par son un `↩ 10`, no diez cuadros encimados.
Sin esa regla, una sesión de cuarenta mensajes termina siendo una pared de
globos, que es de lo que el mapa venía a sacarnos.

## El carril de abajo

Un subagente pasa a ser `SessionSubagent`: qué se le pidió, qué razona, qué
herramientas usó y qué devolvió. Se guarda **con la sesión** —lo que devolvió
es historia del hilo, igual que un mensaje— y se relee como cortado si la app
se cerró con él a medias: no hay proceso que lo devuelva.

Se acuerda de **qué paso** lo abrió, no solo de qué miembro: con cuatro pasos
del mismo miembro, colgarlo del primero lo pondría bajo un nodo que ya había
terminado.

**Los tokens de un subagente no existen**: el CLI los suma dentro del turno
del padre y no los separa. El nodo hijo muestra tiempo y herramientas, y en
«números» dice *al padre* en vez de inventar una cifra.

### Cuántos se dibujan

Cuatro por padre; el resto entra en una píldora que se abre. Es un tope de
**dibujo** y nada más: no limita cuántos puede abrir un agente ni cambia lo
que corre. Un padre que largó doce llenaría el carril y taparía a los demás.

## Entrar a un nodo

Un clic abre el panel del agente, por el costado derecho, con cinco secciones
plegables: **le pidió · cómo razona · qué hizo · qué devolvió · números**, y
abajo el campo para escribirle.

«Escribirle» no significa lo mismo en los tres casos:

- **Miembro del proyecto** — manda un mensaje al canal dirigido a él
  (`@handle`). Es lo que ya hace el chat, desde otro lado.
- **Subagente corriendo** — **no se puede**: el CLI no abre ese canal. El
  panel lo dice donde se intenta, y lo que escribas le llega al miembro que
  lo abrió.
- **Nodo sin dueño vivo** — no hay a quién escribirle, y también se dice.

## Navegar

| Gesto | Qué hace |
|---|---|
| arrastrar / rueda | mover el lienzo |
| ⌘ + rueda, pellizco | zoom del 25 % al 200 %, centrado en el puntero |
| ⌘0 · **Encuadrar** | meter todo en pantalla |
| **Seguir en vivo** | perseguir al nodo que tiene el turno |

Arrastrar un nodo **no lo mueve**: la disposición es fija y no se puede
desordenar. Una disposición que el usuario puede romper es una que hay que
guardar, migrar y arreglar cuando queda rara, y lo que se gana es nada.

Debajo del 50 % el nodo pierde el pie: a esa escala se mira la forma del
recorrido, no los detalles de cada cuadro.

«Seguir en vivo» se apaga sola en cuanto arrastrás — mirar algo y que la
vista se te escape es peor que no seguir nada. Y sin nadie con el turno, la
vista se para en el último que habló, no en el principio: abrir el mapa a
mitad de una sesión y mirar el arranque es mirar el pasado.

## El panel del workflow se retira

En la pestaña Mapa, el panel de 272 px se va: dice lo mismo que el lienzo ya
muestra —los pasos, de quién es cada uno, cuál va— y son 272 px que el mapa
necesita más que él. **El chat no cambia en nada.**

## Dónde vive

| Qué | Dónde |
|---|---|
| El lector del stream, uno solo | `core/services/claude_stream_events.dart` |
| El subagente como dato | `modules/projects/model/session_subagent.dart` |
| El grafo, puro y sin Flutter | `modules/projects/model/session_map.dart` |
| La geometría, determinista | `modules/projects/model/session_map_layout.dart` |
| Las aristas | `modules/projects/ui/widget/map_edges_painter.dart` |
| El nodo | `modules/projects/ui/widget/map_node_card.dart` |
| La leyenda | `modules/projects/ui/widget/map_legend.dart` |
| El panel del agente | `modules/projects/ui/screen/map_node_inspector_screen.dart` |
| El lienzo | `modules/projects/ui/view/session_map_view.dart` |

## Lo que queda afuera

Mover nodos a mano y guardar posiciones, exportar el mapa como imagen, ver
dos sesiones a la vez, y un mapa del proyecto entero cruzando sesiones.
Ninguna es difícil; ninguna es lo que se pidió.

## Ver también

- [F24 — Proyectos y sesiones](24-proyectos-y-sesiones.md), que es el canal
  que el mapa dibuja.
- [F27 — El arranque, y decir que estás esperando](27-arranque-y-espera.md):
  de ahí sale la regla de que nada late si no está pasando.
