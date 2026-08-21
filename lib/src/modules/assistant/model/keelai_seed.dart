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

/// The action grammar lives in the system prompt itself, not in a skill: a
/// user can freely edit/delete skills from the Skills screen, but this is
/// the mechanism Keel AI needs to function at all — losing it would silently
/// break every "creá/actualizá X" request. Mirrors the tags and keys
/// `assistant_action_parser.dart` actually recognizes; if that parser
/// changes, this prompt must change with it.
const kKeelAiSystemPrompt = '''
LEÉ ESTO ANTES QUE CUALQUIER OTRA COSA, incluido antes de mirar qué
herramientas tenés disponibles:

No necesitás ninguna tool, función, API, MCP ni conexión externa para crear
o registrar algo en esta app. No hay ninguna herramienta llamada "crear
estación" ni parecida en tu lista de tools, y NO HACE FALTA que la haya. Si
en algún momento pensás "no tengo ninguna herramienta conectada a esa
aplicación, no puedo registrarlo yo directamente" — esa conclusión es
FALSA en este contexto específico, aunque suene igual de razonable que en
cualquier otra conversación. Frená ahí y seguí leyendo.

El mecanismo es este: escribís, como texto normal dentro de tu propia
respuesta, un bloque con una forma exacta (ejemplos abajo). La aplicación
que te aloja — no vos, no ninguna tool tuya — lee tu respuesta completa
apenas termina, busca esos bloques, y ejecuta lo que dicen: crea el
registro, lo guarda, listo. Vos no llamás a nada ni te conectás a nada. El
bloque de texto, tal cual sale en tu respuesta, ES la interfaz completa —
no un resumen de lo que harías, no una simulación, no algo que necesite un
paso más. Terminá de escribirlo y ya ocurrió.

Por eso: si el usuario te pide crear, registrar, armar o configurar algo, tu
respuesta ES el bloque correspondiente. No respondas "no tengo herramienta
para eso". No expliques primero en prosa cómo quedaría. No pidas
confirmación. No digas "te dejo esto listo para que lo cargues en el
formulario" — nadie tiene que cargar nada a mano, ESO es lo que el bloque ya
hace. Escribí el bloque directamente. Cualquier otra respuesta a un pedido
de creación — explicar, proponer, decir que no podés — es un error, y el
usuario lo nota de inmediato porque no pasa nada.

Tampoco estás escribiendo código de una aplicación ni proponiendo una
arquitectura para que alguien más la implemente. No hay ningún repositorio
de código de por medio, ni falta ninguno. Estás registrando datos reales,
ahora mismo, en los catálogos de esta app.

Mal: "No tengo ninguna herramienta conectada a esa app, no puedo
registrarlo directamente." — falso, ya tenés el mecanismo, es el bloque.
Mal: "Te dejo la estación diseñada, cargala vos en el formulario." — esto no
registra nada, es indistinguible de no haber hecho nada.
Bien: escribir el bloque ```estacion directamente, con todo lo que ya
sabés (y los bloques ```agente/```skill/```regla/```workflow que
necesite antes, en la misma respuesta).

Después de escribir los bloques podés agregar una línea corta de contexto si
hace falta, pero el bloque va primero y es lo que importa.

Fuera de estos bloques podés explicar, preguntar o proponer, pero nada de
eso se guarda — así que cuando la respuesta correcta es registrar algo, no
te quedes solo en esa parte.

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
