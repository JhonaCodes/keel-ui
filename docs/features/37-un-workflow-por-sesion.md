# F37 — Un workflow por sesión

## Qué problema resuelve

Un proyecto hace trabajos de clases distintas. Armar la carpeta `TASKS/` no es
resolver un ticket, y evaluar un requerimiento que llegó de otro proyecto no
es ninguna de las dos. Cada uno quiere otra fila de agentes.

Pero el workflow era del **proyecto**:

```dart
final String? activeWorkflowId;   // UNO, para todo lo que el proyecto haga
```

Y peor: no había ninguna pantalla que lo cambiara. `setActiveWorkflow` se
llamaba desde una tool MCP y de ningún otro lado, así que al crear el proyecto
quedaba `workflowIds.first` y ahí se quedaba. Le atabas cinco workflows y
corría el primero, siempre. Los otros cuatro eran decoración.

El síntoma más caro estaba a la vista: **«Definir el formato» corría el
workflow de tickets**. Escribir unos markdown pasaba por implementador →
auditor → verificador → entrega, y terminaba abriendo un PR en draft. Lo único
que distinguía esa sesión de un ticket era un booleano:

```dart
final bool isFormatSession;   // + una skill inyectada a mano en el prompt
```

Ese booleano era el síntoma, no la solución. Existía **porque había un solo
slot**: sin poder elegir workflow, cada clase de trabajo nueva se resolvía con
otra bandera. El caso siguiente —requerimientos— habría pedido
`isRequirementSession`, y así.

## El workflow baja a la sesión

```dart
class Session {
  final String workflowId;   // con cuál corre ESTA sesión
}
```

Nada de la navegación se toca. `WorkspaceViewModel` no sabe que los workflows
existen, y **la sesión ya era la unidad de navegación**: agregarle un campo no
roza esa máquina.

Quién elige, y por qué no hace falta un agente que decida:

| Quién abre la sesión | Con qué workflow | ¿Hay que pensarlo? |
|---|---|---|
| «Definir el formato» | el de formato | no, es el de la app |
| «Tomar y evaluar» un requerimiento | el que elijas al tomarlo | solo si el destino tiene más de uno |
| Un trabajo de la API | el de por defecto del proyecto | no hay nadie que elija |
| «Nueva sesión» | el de por defecto, cambiable | ahí sí, con un click |

Un agente router habría costado **un turno de CLI por sesión** para decidir
algo que el que llama ya tiene en la mano en tres de los cuatro casos. En el
cuarto, un selector es un click, cuesta cero tokens y no se equivoca.

Ahí es donde `whenToApply` por fin sirve para algo: se escribía, se guardaba y
se mostraba… y no lo leía nadie para decidir. Ahora es el texto que se lee al
elegir.

**Se cambia solo antes de arrancar.** Con pasos ya corridos, media sesión
sería de una fila de agentes y la otra media de otra, y el `3/7` del sidebar
contaría sobre una escala que esa sesión nunca usó. La ficha del encabezado se
apaga y dice por qué.

## El workflow declara lo suyo

Las tres cosas que colgaban de `isFormatSession` no eran del *tipo de sesión*:
eran del *trabajo*. Así que las declara el workflow.

```dart
final List<String> skillNames;   // skills que suma a TODOS sus turnos
final bool buildsRoadmap;        // este workflow CONSTRUYE la carpeta de tareas
```

- **Skills**: distintas de las del agente. Las del agente son *quién es* —un
  experto en Flutter lo es en todos lados—; las del workflow son *qué está
  haciendo*. El mismo agente formateando la carpeta necesita saber el formato;
  ese mismo agente resolviendo un ticket, no.
- **`buildsRoadmap`**: sus turnos reciben el lector del roadmap **aunque la
  carpeta todavía no exista** —es justo el que la está creando— y al cerrar se
  chequea el formato antes de sellar la sesión.

Con eso, `isFormatSession` desaparece. «La sesión de formato» pasa a ser «la
sesión que corre el workflow que arma el roadmap», que es lo que siempre fue.

## El workflow de formato

Se siembra en cada arranque, como el skill:

```
keel-formato-de-tareas
  cuándo: el proyecto no tiene TASKS/, o la tiene ilegible
  1 paso · *  ·  skill: keel-formato-de-tareas  ·  buildsRoadmap
```

Un solo paso, y con **`*` de puesto**. Cualquier otra cosa lo rompería en la
mitad de los proyectos: esto no es trabajo de un `implementador` ni de un
`auditor`, y exigir un rol que el proyecto no tenga sería negarle a un
proyecto nuevo justo lo que más necesita. `*` significa «cualquiera del
proyecto» y lo resuelve `memberForRole`; si el proyecto no tiene **ningún**
agente, el mensaje lo dice así en vez de mandarte a buscar un puesto que no
existe.

Es de la app y no del proyecto: aparece entre los elegibles sin que haya que
engancharlo, porque obligar a configurarlo sería obligar a configurar lo único
que un proyecto recién creado necesita sí o sí.

## Lo guardado antes

Una sesión vieja no trae con qué corrió. Al abrir la app se le escribe uno:

| Lo que tenía guardado | Lo que queda |
|---|---|
| `isFormatSession: true` | el workflow de formato |
| `isFormatSession: false` | el de por defecto del proyecto |

Es una migración de una sola vez, no un `?? default` colgando para siempre: la
lectura deja una marca (`migrar:formato`), `_revived` la cambia por el id de
verdad y el guardado siguiente ya escribe el id.

## Lo que viaja

Un workflow empaquetado (F33) se lleva **sus skills** en la clausura: sin eso,
del otro lado llega un flujo que le pide a sus turnos un saber que ahí no
existe. Y `*` se saltea al buscar candidatos por puesto — no es un rol que
falte, es que no hace falta ninguno.

## Dónde vive

| Qué | Dónde |
|---|---|
| El campo de la sesión y su migración | `modules/projects/model/session.dart` |
| Skills y `buildsRoadmap` | `modules/workflows/model/workflow.dart` |
| El puesto `*` | `modules/agent_profiles/model/agent_profile.dart` |
| El workflow de formato, sembrado | `modules/projects/model/roadmap_format_skill.dart` |
| Elegir, y cuándo se puede | `modules/projects/viewmodel/projects_viewmodel.dart` |
| El selector | `modules/workflows/ui/screen/workflow_picker_panel.dart` |
| La ficha del encabezado | `modules/projects/ui/view/session_chat_view.dart` |
