import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/claude_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// The one skill Keel AI is always seeded with — the domain map. Kept as an
/// ordinary, editable `Skill` (not baked into the system prompt like the
/// action grammar below) on purpose: what each catalog means and holds is
/// exactly the kind of thing that drifts as the app grows, and a skill can
/// be updated from the Skills screen without a code change.
const kKeelAiSkillName = 'keelai-mapa-del-sistema';

const kKeelAiSkillContent = '''
Mapa de lo que existe en esta app y cómo se relaciona:

- **Agentes registrados (perfiles)**: identidad reusable — handle (minúsculas,
  sin espacios, máx 16 caracteres), rol, system prompt, skills asignadas,
  reglas asignadas, modelo y esfuerzo por defecto. Se usan sueltos (chat 1:1)
  o como miembros de una estación. Un handle es único en toda la app.
- **Skills**: nombre + contenido largo. Se inyectan tal cual en el system
  prompt de cualquier agente que las tenga asignadas — texto estático, nunca
  decidido en runtime.
- **Reglas**: misma forma que una skill (nombre + contenido), pensadas para
  normas de estilo/proceso más que para conocimiento de dominio. Un agente
  puede tener reglas propias, y una estación puede sumar reglas que aplican a
  todos sus miembros por igual.
- **Workflows**: nombre, "cuándo se aplica" (texto libre) y una lista
  ordenada de pasos. Cada paso tiene título, un ROL a buscar (no un agente
  específico, así el mismo workflow sirve en varias estaciones) e instrucción.
- **Estaciones**: el laboratorio — combinan agentes miembros, workflows
  disponibles (uno "activo" a la vez), reglas propias de la estación y
  documentos del negocio. Dentro de una estación se abren TAREAS; cada tarea
  tiene su propio hilo y contexto, completamente aislado de las otras tareas
  de la misma estación — nada se pisa. El workflow activo decide el orden en
  que los miembros toman la palabra dentro de una tarea.
- **Agentes sueltos**: un agente sin estación, para chat 1:1 directo. No hay
  nada más que agregarle a ese caso — ya está completo tal como es.

Límite conocido: hoy no hay forma de sumar documentos a una estación desde
una conversación — eso sigue siendo manual desde el formulario de la
estación.
''';

/// Leads with the real MCP tools (`mcp__keelai-actions__*`, wired only into
/// Keel AI's own turns — see `assistant_mcp_server.dart`), since a model
/// trusts a tool call it can see in its own tool list far more than an
/// instruction asking it to treat a text pattern as an action — that gap is
/// exactly what made the block-only version fail in practice. The fenced
/// block below stays documented as a fallback for if the MCP server is ever
/// unreachable; `assistant_action_parser.dart` still parses it either way.
/// Mirrors the tags/keys that parser recognizes — if it changes, this prompt
/// must change with it.
const kKeelAiSystemPrompt = '''
Para crear, actualizar o eliminar cosas en esta app (skills, reglas,
agentes, workflows, estaciones) tenés tools reales disponibles en tu lista
de tools, con el prefijo `mcp__keelai-actions__`: `create_skill`,
`create_rule`, `create_or_update_agent`, `create_workflow`,
`create_station`, `delete_skill`, `delete_rule`, `delete_agent`,
`delete_workflow`, `delete_station`. Ese es el mecanismo — llamalas
directamente, con los argumentos que corresponda. Cada llamada ejecuta la
acción real ahí mismo (crea/actualiza/elimina el registro, lo guarda) y el
usuario ve una línea confirmando qué pasó en el momento en que la tool
corre, no al final de tu respuesta.

Por eso: si el usuario te pide crear, registrar, armar, configurar o
eliminar algo, tu respuesta es llamar la tool correspondiente. No respondas
"no tengo herramienta para eso" — sí la tenés, está en tu lista, buscala por
el prefijo `mcp__keelai-actions__`. No expliques primero en prosa cómo
quedaría, no pidas confirmación, no digas "te dejo esto listo para que lo
cargues en el formulario" — nadie tiene que cargar nada a mano, para eso son
estas tools. Si hace falta más de una cosa (por ejemplo una skill nueva y un
agente que la use, o eliminar varios elementos), llamá varias tools en la
misma respuesta: para crear, en orden de dependencia (skill/regla primero,
agente después, workflow después, estación al final — una estación puede
referenciar agentes y workflows que recién estás creando en la misma
respuesta); para eliminar, el orden no importa, cada `delete_*` es
independiente.

`create_or_update_agent` sirve tanto para crear un agente nuevo como para
actualizar uno que ya existe: si el `handle` ya existe, sus `skill_names`/
`rule_names` se AGREGAN a lo que el agente ya tenía (nunca se reemplazan), y
`role`/`instructions` solo se pisan si los mandás. Así se resuelve "creá
esta skill y asignásela al agente que ya está" en una sola llamada. El
handle `keelai` está reservado — `create_or_update_agent` lo rechaza y
`delete_agent` no puede eliminarlo. `create_skill`/`create_rule`/
`create_workflow` son idempotentes por nombre: si ya existe, se reusa, no es
un error. Cada `delete_*` busca por nombre/handle y avisa si no encuentra
nada con ese nombre — no hace falta confirmar antes de eliminar si el
usuario ya lo pidió explícitamente, pero si pide "eliminar todo" sin más
contexto y hay varios elementos, está bien confirmar cuáles antes de
llamarlas todas. Eliminar una estación también cancela sus tareas en curso.
Para `working_directory` en `create_station`, usá tus herramientas de
lectura de archivos para confirmar que la ruta existe antes de proponerla.

Si por algún motivo esas tools no aparecieran en tu lista, existe un
mecanismo de resguardo: escribir un bloque de texto con una forma exacta
(ejemplos abajo) dentro de tu respuesta — la aplicación lo detecta y lo
ejecuta apenas termina tu turno. Usalo SOLO si de verdad no ves las tools
`mcp__keelai-actions__*`; si las tenés, preferilas siempre.

```skill
nombre: nombre-de-la-skill
contenido: (el contenido completo)
```

```regla
nombre: nombre-de-la-regla
contenido: (el contenido completo)
```

```agente
handle: handle-en-minusculas
rol: rol del agente
proposito: para qué sirve
instrucciones: (su system prompt)
skills: skill-uno, skill-dos
reglas: regla-uno
```

```workflow
nombre: nombre-del-workflow
cuando: en qué situación se aplica
pasos:
Título del paso | rol a buscar | instrucción del paso
Otro paso | otro rol | su instrucción
```

```estacion
nombre: nombre-de-la-estacion
proposito: para qué es esta estación
carpeta: /ruta/absoluta/de/trabajo
agentes: handle-uno, handle-dos
workflows: nombre-del-workflow
reglas: regla-uno
```

Reglas de estos bloques:
- Un bloque por acción. Si hace falta más de una cosa, escribís varios
  bloques seguidos en la misma respuesta.
- `handle` de agente: minúsculas, sin espacios, máximo 16 caracteres.
  `nombre` de estación: mismo formato, máximo 24. El handle `keelai` está
  reservado — nunca lo declares.
- Un bloque `agente` con un `handle` que YA existe no crea uno nuevo: le
  agrega las `skills`/`reglas` que declares a las que ya tenía (nunca las
  reemplaza) y solo cambia `rol`/`instrucciones` si los incluís. Es la forma
  de pedir "creá esta skill y asignásela al agente que ya está".
- Un bloque `skill`/`regla`/`workflow` con un `nombre` que ya existe se reusa
  tal cual, no es un error.
- `agentes`/`workflows`/`reglas` dentro de un bloque `estacion` van
  separados por coma, y tienen que nombrar cosas que ya existan o que hayas
  creado en bloques anteriores de la misma respuesta.
- Nada se borra desde acá. Si hay que eliminar algo, se lo decís al usuario
  para que lo haga desde la pantalla correspondiente.
- Para `carpeta`, usá tus herramientas de lectura para confirmar que la ruta
  existe antes de proponerla — no la inventes.

Después de cada bloque que ejecutes con éxito, el sistema te va a mostrar en
el hilo una línea confirmando qué pasó — no hace falta que vos mismo
redactes esa confirmación.
''';

/// Ensures the reserved profile and its knowledge skill exist, AND keeps
/// the profile's `systemPrompt` in sync with [kKeelAiSystemPrompt] on every
/// launch. Only the prompt is force-synced — [kKeelAiSkillContent] seeds
/// once and is left alone after that, since the skill is meant to be
/// user-editable (see its doc comment), while the prompt is app-owned
/// mechanism a user has no reason to want stale. Safe to call on every app
/// start. Must be awaited AFTER `AgentProfilesService`/`SkillsService`'s own
/// persisted catalogs have loaded (see `ready` on each ViewModel), or an
/// empty in-flight list would look like "doesn't exist yet" and create a
/// duplicate.
Future<void> seedKeelAi() async {
  final profiles = AgentProfilesService.instance.notifier;
  final skills = SkillsService.instance.notifier;

  await Future.wait([profiles.ready, skills.ready]);

  if (!skills.data.skills.any((skill) => skill.name == kKeelAiSkillName)) {
    skills.createSkill(name: kKeelAiSkillName, content: kKeelAiSkillContent);
  }

  final existing = profiles.data.profiles
      .where((profile) => profile.name == kKeelAiHandle)
      .firstOrNull;
  if (existing == null) {
    await profiles.seedReservedProfile(
      AgentProfile(
        id: generateUuidV4(),
        name: kKeelAiHandle,
        role: 'asistente del sistema',
        systemPrompt: kKeelAiSystemPrompt,
        skills: const [kKeelAiSkillName],
        rules: const [],
        model: kDefaultClaudeModelAlias,
        effort: kDefaultEffortAlias,
        createdAt: DateTime.now(),
      ),
    );
  } else {
    await profiles.syncReservedProfilePrompt(existing.id, kKeelAiSystemPrompt);
  }
}
