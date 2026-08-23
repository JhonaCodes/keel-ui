# F32 — Una sola navegación

## Qué problema resuelve

Un tablero abierto y tocás una sesión: no pasa nada. El menú marcaba la
sesión, el centro seguía en el tablero, y no había forma de volver salvo
tocar otra cosa primero.

No era un bug de una fila. **Qué se está mirando estaba escrito en cuatro
lugares** y cada uno se podía mover sin los otros:

| Dónde | Qué guardaba |
|---|---|
| `_focus` dentro de `AgentsScreen` | agente · proyecto · requerimiento · tablero |
| `_openBoardId`, al lado | cuál tablero |
| `ProjectsState.selectedProjectId` | qué proyecto |
| `Project.activeSessionId` | qué sesión, y si había alguna |

La fila de una sesión llamaba directo a `selectSession`, que mueve el cuarto
y no toca el primero. La fila de Estado, igual. Un trabajo que entraba por la
API abría una sesión en un proyecto que ni siquiera era el que estabas
mirando. Cada camino movía su mitad y la otra quedaba donde estaba.

## Qué es

Un **lente**: qué muestra el área central, en un solo dato, con un solo
dueño.

```
agent · requirement · projectState · boards · board · session
```

`WorkspaceViewModel` es el único que navega, y cada `openX` hace las **dos**
cosas que antes estaban separadas: mueve la selección en el ViewModel que
corresponda y deja dicho qué lente queda.

```
openSession(proyecto, sesión)  → selectSession(...)      + lente sesión
openProjectState(proyecto)     → showProjectState(...)   + lente estado
openBoards(proyecto)           → selectProject(...)      + lente tableros
openBoard(tablero)             →                           lente tablero
openProject(proyecto)          → selectProject(...)      + donde lo dejaste
```

La pantalla no guarda nada: dibuja lo que el lente diga.

## Seleccionar no es navegar

Los ViewModels de abajo **no saben que el lente existe**, y así queda. Es lo
que hace que un trabajo que entra por la API abra su sesión sin arrastrarte a
ella: no pediste ir. Lo mismo con una tool de Keel AI que crea una sesión en
otro proyecto.

El botón «Nueva sesión» sí navega, porque es un botón: la intención está en
el gesto, no en el alta.

## El id no sobrevive al lente

`boardId` solo existe con el lente en `board`. Un id que sobrevive a su lente
es el próximo desfasaje: un tablero borrado hace tres pantallas, todavía
apuntado, esperando a que algo lo dibuje.

Y para lo que se borra **mientras** lo mirás, la vista pregunta antes de
dibujar en vez de pedirle a quien borra que avise:

```dart
workspace.resolved(boardExists: ...)   // board sin tablero → boards
```

Un acuerdo de «acordate de avisarle a la navegación» se cumple dos veces y se
rompe la tercera. Preguntar no se olvida.

## Lo que se ve del cambio

Un proyecto abierto muestra **tres secciones hermanas**, escritas con el
mismo widget y por eso leídas como iguales:

```
# aulamas-portal
  ·  Estado                    0%
  ▾  Tableros                   2
       • Lanzar oferta          ×
       • Push de prueba         ×
  ▾  Sesiones                   2
       • Sesión nueva      1/8  ×
       + Nueva sesión
```

Antes Estado era una fila, TABLEROS un encabezado en versalitas y las
sesiones no tenían encabezado ninguno: tres formas distintas para tres cosas
que están al mismo nivel.

La fila navega; el galón abre y cierra la lista. Son dos gestos porque son
dos cosas: ir a los tableros y ver cuáles hay no son lo mismo. Estado lleva
un punto y no un galón —un triángulo que no abre nada es una promesa que la
fila no cumple— pero ocupa el mismo lugar, que es lo que mantiene las tres
alineadas.

### Y el menú bajó de altura

Dos cosas lo estaban inflando:

- El texto de «todavía no hay tableros» gastaba cuatro líneas de menú para
  decir que no había nada, sin nada que apretar. Se fue a la pantalla, que es
  donde se puede hacer algo al respecto.
- Cada cruz reclamaba **48 puntos de alto** —la medida de un dedo, en una app
  de escritorio— y la fila entera pasaba de 30 a 54. Seis filas con cruz eran
  media pantalla de menú.

## Dónde vive

| Qué | Dónde |
|---|---|
| El lente, como dato | `modules/workspace/model/workspace_lens.dart` |
| El único que navega | `modules/workspace/viewmodel/workspace_viewmodel.dart` |
| La fila de sección, compartida | `core/ui/sidebar_section_row.dart` |
| Las tres secciones | `modules/projects/ui/view/projects_sidebar.dart` |
| La sección Tableros | `modules/boards/ui/widget/boards_group.dart` |
| La pantalla de tableros del proyecto | `modules/boards/ui/view/project_boards_view.dart` |

## Verificación

1. Con un tablero abierto, tocar una sesión → se abre la sesión.
2. Con un tablero abierto, tocar Estado → se abre el estado.
3. Tocar Tableros sin ninguno → la pantalla con los dos caminos.
4. Pedírselo a Keel AI desde ahí → la ventana se abre con el pedido hecho.
5. Borrar el tablero que estás mirando → cae en la lista, no en un hueco.
6. Cerrar la única sesión → el centro ofrece abrir otra.
7. Un trabajo por la API en otro proyecto → **no** te mueve de donde estás.

## Ver también

- [F25](25-estado-del-proyecto.md), que era el lente deducido.
- [F29](29-tableros.md), el que rompió la deducción.
