import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';
import 'package:keel_ui/src/integrations/session_plan_mcp/session_plan_mcp_server.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/member_tuning.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/repository/projects_repository.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Matches an `@handle` mention of a project member. Same shape the profile
/// name validator enforces, so a mention can only ever name a real handle.
final RegExp _mentionPattern = RegExp(r'@([a-z0-9_-]{1,16})');

/// The fields a `\`\`\`agente` declaration block recognizes. Parsed by the
/// shared [parseFencedBlocks] — kept deliberately rigid so reading it is a
/// decision, not a guess about prose.
const _agentDeclarationKeys = {'handle', 'rol', 'proposito', 'instrucciones'};

/// Las claves de los bloques ```plan y ```cumplido con los que un miembro
/// codex escribe y marca el plan. Codex no recibe servidores MCP, así que
/// las tools del plan no existen para él — mismo patrón que ```agente.
const _planBlockKeys = {'puntos'};

/// Cómo abre el mensaje de cierre cuando la sesión queda con puntos
/// pendientes. Es también la compuerta de las palabras débiles de
/// [ProjectsViewModel._looksLikeContinue]: "dale" cuenta como continuar solo
/// si lo último del hilo empieza así — es decir, si se acaba de invitar.
const _cycleInvitePrefix = 'La sesión NO queda terminada';

/// Cómo terminó un turno de CLI: si produjo una respuesta usable y cuál fue.
///
/// Antes el turno no devolvía nada y las decisiones que dependían de él se
/// tomaban mirando el hilo — la "respuesta" de una consulta era el último
/// mensaje de la sesión, fuera de quien fuera, y un paso fallido dejaba al
/// ciclo marchar igual por los pasos restantes.
typedef TurnOutcome = ({bool ok, String answer});

/// Un canal es una conversación, no una cinta de producción. Sin esta
/// distinción cada mensaje entra como orden de trabajo: el usuario pregunta
/// "¿cuál es la siguiente sesión?" y el agente sale a correr comandos, abrir
/// tickets y tocar archivos, porque todo lo demás que lleva en el turno —sus
/// skills de proceso, las reglas del proyecto— habla de ejecutar.
const _askVsWorkPrompt =
    'PREGUNTA O PEDIDO: un mensaje del usuario en el canal puede ser un '
    'PEDIDO DE TRABAJO o una PREGUNTA. Distinguilos antes de mover un dedo.\n'
    '- Es una PREGUNTA cuando quiere saber algo: en qué va la sesión, qué '
    'sigue, qué decidiste, qué dice un documento, por qué hiciste algo. '
    'Contestá con lo que ya sabés, o leyendo lo mínimo para responder. NO '
    'corras comandos, no modifiques archivos, no abras ni cierres nada, no '
    'empieces el trabajo del paso siguiente. Una respuesta de dos líneas es '
    'una respuesta completa si eso alcanza.\n'
    '- Es un PEDIDO DE TRABAJO cuando te dice qué hacer o te da el material '
    'para hacerlo. Ahí sí ejecutás lo que corresponde a tu paso.\n'
    'Ante la duda, preguntá qué quiere antes de ejecutar: una pregunta '
    'contestada de más cuesta un turno; trabajo que nadie pidió cuesta el '
    'turno, el dinero y deshacer lo que tocaste.\n'
    'Esta decisión va primero: cualquier otra instrucción del estilo "hacé '
    'el cambio de verdad con tus herramientas de archivo" aplica recién '
    'DESPUÉS de decidir que el mensaje es un pedido de trabajo. Ante una '
    'pregunta, respondés y no tocás nada.';

/// La definición de ENTREGA. Vive en el prompt porque no vivía en ningún
/// lado: ni la doc ni los workflows decían qué es "terminar", y sin esto
/// cada flujo lo inventaba — mergear, no abrir PR, o abrir uno nuevo por
/// ciclo. Solo entra en proyectos cuyo directorio de trabajo tiene git.
const _deliveryPrompt =
    'ENTREGA: el resultado de una sesión que toca código se entrega como PULL '
    'REQUEST EN DRAFT — nunca mergeado ni marcado listo para review: eso lo '
    'decide el usuario. En el primer ciclo que toque código, creá una rama '
    'para la sesión, commiteá ahí y abrí el PR en draft (`gh pr create '
    '--draft`). En los ciclos siguientes, commiteá a la MISMA rama del mismo '
    'PR — no abras otro. Apenas el PR exista, dejá su URL completa en una '
    'línea propia de tu respuesta, FUERA de bloques de código: así queda '
    'clickeable y el encabezado de la sesión muestra "PR #N". Cerrar el '
    'último ciclo sin la URL del PR en el hilo es cerrar sin entregar.';

/// Nothing an agent does may be invisible. The CLI can spawn subagents of its
/// own, which run outside the channel, cost money, and answer to nobody the
/// user registered — so they are forbidden outright, and the way to get a
/// specialist is to declare it and have the app register it in the open.
/// El título con el que nace una sesión. Vale como marca de "todavía no
/// tiene nombre propio": mientras siga siendo este, el primer pedido la
/// renombra sola.
const kDefaultSessionTitle = 'Sesión nueva';

const _noBackgroundWorkPrompt =
    'REGLA DEL CANAL, POR ENCIMA DE CUALQUIER OTRA COSA: no lanzás trabajo '
    'en segundo plano. Nada de subagentes propios, nada de delegar a procesos '
    'que el usuario no ve. Todo lo que pase tiene que pasar en este hilo, a '
    'la vista.\n'
    'Si te falta un especialista que el proyecto no tiene, NO lo inventes ni '
    'lo simules: declaralo con un bloque exactamente así, y el sistema lo '
    'registra como agente real, con vos como creador.\n'
    '```agente\n'
    'handle: auditor\n'
    'rol: auditor de seguridad\n'
    'proposito: revisa cambios buscando fugas de credenciales\n'
    'instrucciones: (el system prompt con el que va a trabajar)\n'
    '```\n'
    'El handle va en minúsculas, sin espacios, máximo 16 caracteres. Después '
    'del bloque seguí escribiendo normalmente: en tu próximo turno ese agente '
    'ya es un compañero al que podés mencionar con su @handle. Declaralo solo '
    'cuando de verdad haga falta — cada agente nuevo es permanente y queda a '
    'la vista del usuario.';

class ProjectsViewModel extends ViewModel<ProjectsState> {
  ProjectsViewModel() : super(const ProjectsState());

  ProjectsRepository get _repository => ProjectsRepository();

  /// Keyed by **session**, not by project: a project can have several sessions in
  /// flight at once, each owning its own runner. Within one session the turns
  /// still run strictly in sequence, so the agents of a single session never
  /// write files on top of each other.
  final Map<String, TaskRun> _runningSessions = {};
  final Set<String> _stoppedSessionIds = {};

  /// Who was blocked when a session asked you for a permission, so granting it
  /// resumes that member and not whoever happened to speak last.
  final Map<String, String> _permissionBlockedProfileBySession = {};

  /// `turn:asker>target` pairs already consulted. Scoped to a single turn on
  /// purpose: it stops two agents rebounding inside one answer, while a new
  /// question from the user opens a fresh turn where they may consult each
  /// other again. Keying it per step instead blocked every later consult for
  /// the rest of that step.
  final Set<String> _consultedPairs = {};

  static const _maxConsultDepth = 3;

  /// Tope de consultas que un turno raíz puede disparar, contando toda su
  /// cadena. La profundidad sola no acota el ANCHO: con cinco miembros, un
  /// turno podía disparar decenas de turnos reales mencionando a todos y
  /// dejando que cada uno mencione a los demás.
  static const _maxConsultsPerRootTurn = 5;

  /// The consult ledger is keyed by turnId, which never repeats — without a
  /// purge it grows for the app's whole lifetime. Cleared whenever no session
  /// is running: no in-flight turn can still need its pairs then.
  void _purgeConsultLedgerIfIdle() {
    if (_runningSessions.isEmpty) _consultedPairs.clear();
  }

  /// Resolves once the persisted projects have loaded — same guarded-ready
  /// pattern as the other catalogs, so the catalog sync (and any MCP-driven
  /// first access) can await real data, and a later
  /// `reinitializeWithContext()` never wipes loaded state.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedProjects();

  @override
  void init() {
    if (_ready == null) updateSilently(const ProjectsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedProjects() async {
    try {
      final projects = await _repository.load();
      updateState(data.copyWith(projects: _revived(projects)));
    } catch (error) {
      Log.e('Failed to load persisted projects', error: error);
    }
  }

  /// No CLI process survives closing the app, so a session that comes back from
  /// disk saying it is running is lying — it was interrupted mid-turn. Left
  /// alone the flag never clears: the composer stays disabled, the progress
  /// bar spins forever, and `sendToChannel` returns early on every message.
  /// The channel looks hung because, as far as the state is concerned, it is.
  List<Project> _revived(List<Project> projects) {
    return [
      for (final project in projects)
        project.copyWith(
          sessions: [
            for (final session in project.sessions)
              session.isRunning ? session.copyWith(isRunning: false) : session,
          ],
        ),
    ];
  }

  // ── alta y configuración ────────────────────────────────────────────

  /// Registers a project. Returns a user-facing error message on failure
  /// (invalid or duplicate name), or null on success.
  String? createProject({
    required String name,
    required String purpose,
    required String workingDirectory,
    required List<String> profileIds,
    required List<String> workflowIds,
    required List<String> ruleNames,
    List<String> hookNames = const [],
    required List<String> knowledgeBaseNames,
    bool maintained = true,
  }) {
    final error = _validateName(name);
    if (error != null) return error;

    final project = Project(
      id: generateUuidV4(),
      name: name,
      purpose: purpose.trim(),
      workingDirectory: workingDirectory.trim(),
      profileIds: profileIds,
      workflowIds: workflowIds,
      ruleNames: ruleNames,
      hookNames: hookNames,
      knowledgeBaseNames: knowledgeBaseNames,
      maintained: maintained,
      activeWorkflowId: workflowIds.isEmpty ? null : workflowIds.first,
      createdAt: DateTime.now(),
    );
    final projects = [...data.projects, project];
    updateState(
      data.copyWith(projects: projects, selectedProjectId: project.id),
    );
    unawaited(_repository.save(projects));
    return null;
  }

  /// Updates a project's configuration. Its sessions are untouched — the project
  /// is the durable part. Returns a user-facing error message, or null.
  String? updateProject(
    String id, {
    required String name,
    required String purpose,
    required String workingDirectory,
    required List<String> profileIds,
    required List<String> workflowIds,
    required List<String> ruleNames,
    List<String> hookNames = const [],
    required List<String> knowledgeBaseNames,
    bool maintained = true,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final projects = data.projects.map((project) {
      if (project.id != id) return project;
      final keepsActive =
          project.activeWorkflowId != null &&
          workflowIds.contains(project.activeWorkflowId);
      return project.copyWith(
        name: name,
        purpose: purpose.trim(),
        workingDirectory: workingDirectory.trim(),
        profileIds: profileIds,
        workflowIds: workflowIds,
        ruleNames: ruleNames,
        hookNames: hookNames,
        knowledgeBaseNames: knowledgeBaseNames,
        maintained: maintained,
        activeWorkflowId: keepsActive
            ? project.activeWorkflowId
            : (workflowIds.isEmpty ? null : workflowIds.first),
        clearActiveWorkflow: !keepsActive && workflowIds.isEmpty,
      );
    }).toList();

    updateState(data.copyWith(projects: projects));
    unawaited(_repository.save(projects));
    return null;
  }

  /// Le cambia el nombre y nada más.
  ///
  /// Aparte de [updateProject] a propósito: renombrar es un gesto de una
  /// línea en el sidebar, y pasar por el formulario entero obligaría a
  /// reenviar agentes, workflows y reglas para mover un string.
  ///
  /// Es seguro por construcción: nada apunta a un proyecto por nombre salvo
  /// la ruta de la jobs API y las tomas del roadmap, que vencen solas.
  String? renameProject(String id, String name) {
    final trimmed = name.trim();
    final error = _validateName(trimmed, excludingId: id);
    if (error != null) return error;

    final projects = data.projects
        .map(
          (project) =>
              project.id == id ? project.copyWith(name: trimmed) : project,
        )
        .toList();
    updateState(data.copyWith(projects: projects));
    unawaited(_repository.save(projects));
    return null;
  }

  void deleteProject(String id) {
    for (final session in _projectById(id)?.sessions ?? const <Session>[]) {
      _runningSessions.remove(session.id)?.cancel();
      _stoppedSessionIds.remove(session.id);
    }
    final projects = data.projects.where((s) => s.id != id).toList();
    final clearing = data.selectedProjectId == id;
    updateState(
      ProjectsState(
        projects: projects,
        selectedProjectId: clearing ? null : data.selectedProjectId,
      ),
    );
    unawaited(_repository.save(projects));
  }

  void selectProject(String id) {
    updateState(data.copyWith(selectedProjectId: id));
  }

  /// Adds a rule to the project without leaving the channel — the panel is
  /// where you notice a rule is missing, so it is also where you add it.
  void addRule(String projectId, String ruleName) {
    _updateProject(projectId, (project) {
      if (project.ruleNames.contains(ruleName)) return project;
      return project.copyWith(ruleNames: [...project.ruleNames, ruleName]);
    });
    unawaited(_persist());
  }

  void removeRule(String projectId, String ruleName) {
    _updateProject(
      projectId,
      (project) => project.copyWith(
        ruleNames: project.ruleNames.where((r) => r != ruleName).toList(),
      ),
    );
    unawaited(_persist());
  }

  void addKnowledgeBase(String projectId, String baseName) {
    _updateProject(projectId, (project) {
      if (project.knowledgeBaseNames.contains(baseName)) return project;
      return project.copyWith(
        knowledgeBaseNames: [...project.knowledgeBaseNames, baseName],
      );
    });
    unawaited(_persist());
  }

  void removeKnowledgeBase(String projectId, String baseName) {
    _updateProject(
      projectId,
      (project) => project.copyWith(
        knowledgeBaseNames: project.knowledgeBaseNames
            .where((name) => name != baseName)
            .toList(),
      ),
    );
    unawaited(_persist());
  }

  /// Fija con qué motor corre [profileId] **en este proyecto**: proveedor,
  /// modelo y esfuerzo. Cada campo en null vuelve a lo que diga el perfil,
  /// y un ajuste que ya no cambia nada se borra en vez de quedar guardado
  /// como un override vacío que la UI marcaría igual.
  void setMemberTuning(
    String projectId,
    String profileId, {
    AgentProvider? provider,
    String? model,
    String? effort,
  }) {
    final tuning = MemberTuning(
      provider: provider,
      model: model,
      effort: effort,
    );
    _updateProject(projectId, (project) {
      final tunings = Map<String, MemberTuning>.from(project.memberTuning);
      if (tuning.isEmpty) {
        tunings.remove(profileId);
      } else {
        tunings[profileId] = tuning;
      }
      return project.copyWith(memberTuning: tunings);
    });
    unawaited(_persist());
  }

  void clearMemberTuning(String projectId, String profileId) =>
      setMemberTuning(projectId, profileId);

  // ── plan de trabajo de una sesión ────────────────────────────────────

  /// Fija el plan de la sesión. Reemplaza el anterior, pero **conserva el
  /// estado de los puntos cuyo texto no cambió**: replanificar a mitad de
  /// camino no puede desmarcar lo que ya se hizo.
  ///
  /// Deja además el plan escrito en el hilo. El sidebar muestra el plan VIVO
  /// —qué falta ahora, en dos palabras por punto— y el hilo, el plan tal como
  /// se acordó en ese momento: si a los diez turnos cambió, la conversación
  /// conserva las dos versiones y se ve qué se replanificó.
  void setSessionPlan(
    String projectId,
    String sessionId,
    List<PlanEntry> entries,
  ) {
    final anterior = planOf(projectId, sessionId);

    _updateSession(projectId, sessionId, (session) {
      // La clave es el texto NORMALIZADO: un retoque de mayúsculas, acentos o
      // puntuación al replanificar no puede desmarcar un punto ya hecho —
      // eso mandaba el ciclo a trabajar de nuevo lo que ya estaba.
      final anteriores = {
        for (final item in session.plan) normalizeForMatch(item.text): item,
      };
      return session.copyWith(
        plan: [
          for (final entry in entries)
            if (entry.text.trim().isNotEmpty)
              // El puesto se reescribe siempre —replanificar puede cambiar a
              // quién le toca— pero el estado del punto se conserva si el
              // texto no cambió.
              (anteriores[normalizeForMatch(entry.text)] ??
                      SessionPlanItem(
                        id: generateUuidV4(),
                        text: entry.text.trim(),
                      ))
                  .copyWith(ownerRole: entry.ownerRole),
        ],
      );
    });

    final plan = planOf(projectId, sessionId);
    if (plan.isNotEmpty) {
      final buffer = StringBuffer(
        anterior.isEmpty
            ? 'PLAN DE TRABAJO · ${plan.length} puntos'
            : 'PLAN REPLANIFICADO · ${plan.length} puntos '
                  '(antes ${anterior.length})',
      );
      for (final item in plan) {
        buffer.write('\n${item.done ? '✓' : '○'}  ${item.text}');
      }
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.system,
          text: buffer.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }

    unawaited(_persist());
  }

  /// Marca puntos del plan como hechos. Acepta el id o el texto (comparado
  /// con [normalizeForMatch]): el
  /// modelo tiene los dos a la vista y exigir el id convierte un acierto en
  /// un fallo silencioso. Devuelve los que no encontró.
  List<String> completePlanItems(
    String projectId,
    String sessionId, {
    required List<String> items,
    String? byProfileId,
  }) {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (session == null) return items;

    final buscados = items.map((entry) => entry.trim()).toSet();
    final encontrados = <String>{};

    // Id textual, o texto con la misma tolerancia que `setSessionPlan`: exigir
    // el texto EXACTO convertía un acierto con otra mayúscula o sin la tilde
    // en un fallo silencioso.
    String? matchDe(SessionPlanItem item) {
      for (final buscado in buscados) {
        if (buscado == item.id ||
            normalizeForMatch(buscado) == normalizeForMatch(item.text)) {
          return buscado;
        }
      }
      return null;
    }

    final plan = [
      for (final item in session.plan)
        if (matchDe(item) case final buscado?)
          () {
            encontrados.add(buscado);
            return item.copyWith(done: true, doneByProfileId: byProfileId);
          }()
        else
          item,
    ];

    _updateSession(
      projectId,
      sessionId,
      (current) => current.copyWith(plan: plan),
    );

    // El avance también se cuenta en el hilo, y no como un número suelto: si
    // el paso dice que hizo algo y acá no aparece tildado, la diferencia se
    // ve en el momento y no tres turnos después.
    final marcados = plan.where((item) => item.done && matchDe(item) != null);
    if (marcados.isNotEmpty) {
      final buffer = StringBuffer('PLAN · ${plan.doneCount} de ${plan.length}');
      for (final item in marcados) {
        buffer.write('\n✓  ${item.text}');
      }
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.system,
          text: buffer.toString(),
          timestamp: DateTime.now(),
          authorProfileId: byProfileId,
        ),
      );
    }

    unawaited(_persist());
    return buscados.difference(encontrados).toList();
  }

  /// El plan de una sesión, o vacío si no existe. Para quien lo lee de
  /// afuera del árbol de widgets (el servidor MCP del plan).
  List<SessionPlanItem> planOf(String projectId, String sessionId) {
    final project = _projectById(projectId);
    if (project == null) return const [];
    return _sessionById(project, sessionId)?.plan ?? const [];
  }

  /// Des/marca un punto a mano — el veredicto final es del usuario.
  void togglePlanItem(String projectId, String sessionId, String itemId) {
    _updateSession(projectId, sessionId, (session) {
      return session.copyWith(
        plan: [
          for (final item in session.plan)
            if (item.id == itemId)
              item.copyWith(done: !item.done, clearDoneBy: item.done)
            else
              item,
        ],
      );
    });
    unawaited(_persist());
  }

  void removePlanItem(String projectId, String sessionId, String itemId) {
    _updateSession(projectId, sessionId, (session) {
      return session.copyWith(
        plan: session.plan.where((item) => item.id != itemId).toList(),
      );
    });
    unawaited(_persist());
  }

  /// Renombra una sesión a mano. Un título vacío la devuelve al de fábrica,
  /// que es lo que deja que el primer pedido vuelva a nombrarla sola.
  void renameSession(String projectId, String sessionId, String title) {
    final limpio = title.trim();
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        title: limpio.isEmpty ? kDefaultSessionTitle : limpio,
      ),
    );
    unawaited(_persist());
  }

  void setActiveWorkflow(String projectId, String workflowId) {
    _updateProject(
      projectId,
      (project) => project.copyWith(activeWorkflowId: workflowId),
    );
    unawaited(_persist());
  }

  String? _validateName(String name, {String? excludingId}) {
    final formatError = validateProjectName(name);
    if (formatError != null) return formatError;

    final isTaken = data.projects.any(
      (project) => project.name == name && project.id != excludingId,
    );
    if (isTaken) return 'Ya existe un proyecto con ese nombre.';
    return null;
  }

  // ── sesiones ──────────────────────────────────────────────────────────

  void selectSession(String projectId, String sessionId) {
    _updateProject(
      projectId,
      (project) => project.copyWith(activeSessionId: sessionId),
    );
    unawaited(_persist());
  }

  /// Opens an empty session and selects it. **This is the only way a session is
  /// created** — writing in the channel never spawns one, so a follow-up
  /// question inside a session stays inside that session. Each session is its own
  /// environment: its own thread, its own CLI sessions, independent of the
  /// other sessions in the same project.
  void createSession(String projectId) {
    final session = Session(
      id: generateUuidV4(),
      title: kDefaultSessionTitle,
      createdAt: DateTime.now(),
    );
    _updateProject(
      projectId,
      (project) => project.copyWith(
        sessions: [...project.sessions, session],
        activeSessionId: session.id,
      ),
    );
    unawaited(_persist());
  }

  /// Drops a session and everything it accumulated: its thread and its CLI
  /// sessions. The project keeps its members, workflows, rules and documents.
  void closeSession(String projectId, String sessionId) {
    _runningSessions.remove(sessionId)?.cancel();
    _stoppedSessionIds.add(sessionId);

    _updateProject(projectId, (project) {
      final sessions = project.sessions
          .where((session) => session.id != sessionId)
          .toList();
      final wasActive = project.activeSessionId == sessionId;
      return project.copyWith(
        sessions: sessions,
        activeSessionId: wasActive ? null : project.activeSessionId,
        clearActiveSession: wasActive,
      );
    });
    unawaited(_persist());
  }

  void stopSession(String projectId, String sessionId) {
    final run = _runningSessions.remove(sessionId);
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    // Entre turno y turno no hay TaskRun vivo, pero la corrida sigue. Sin
    // registrar el id igual, Stop en esa ventana era un botón que no hacía
    // nada — y un fan-out de consultas no se podía cortar.
    if (run == null && !(session?.isRunning ?? false)) return;

    _stoppedSessionIds.add(sessionId);
    run?.cancel();

    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.error,
        text: 'Detenido por el usuario.',
        timestamp: DateTime.now(),
      ),
    );
    _finishSession(projectId, sessionId, SessionStatus.failed);
  }

  /// Runs the project's active workflow inside [sessionId], from its first step
  /// to its last. Every member starts from a brand new CLI session, so a session
  /// never inherits context from another one.
  ///
  /// Several sessions can be in flight in the same project: each owns its own
  /// runner and its own sessions, so running one never interrupts another.
  Future<void> _runWorkflow(
    String projectId,
    String sessionId,
    String request,
  ) async {
    final project = _projectById(projectId);
    if (project == null) return;

    final workflow = activeWorkflowOf(project);
    if (workflow == null) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text:
              'Este proyecto no tiene un workflow activo. Agregá uno para que '
              'sepa cómo repartir el trabajo.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    if (workflow.steps.isEmpty) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text: 'El workflow "${workflow.name}" no tiene pasos definidos.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    final trimmed = request;
    _stoppedSessionIds.remove(sessionId);
    // El primer pedido queda guardado en la sesión: los ciclos 2..N corren
    // con el punto del plan como request y sin esto el pedido original
    // desaparecía para cualquier miembro sin sesión previa.
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        isRunning: true,
        request: session.request.isEmpty ? trimmed : session.request,
      ),
    );
    await _persist();

    final messagesAtStart =
        _sessionById(
          _projectById(projectId) ?? project,
          sessionId,
        )?.messages.length ??
        0;

    // El cierre corre adentro del mismo try que los pasos: una excepción ahí
    // también tiene que soltar el canal, no dejar `isRunning` colgado.
    try {
      final steps = await _runSteps(projectId, sessionId, workflow, trimmed);
      _runningSessions.remove(sessionId);
      final stopped = _stoppedSessionIds.remove(sessionId);
      if (!stopped && !steps.ended) {
        await _closeAgainstPlan(
          projectId,
          sessionId,
          workflow,
          messagesAtStart: messagesAtStart,
          lastHandle: steps.lastHandle,
          lastAnswer: steps.lastAnswer,
        );
      }
    } catch (error) {
      return _abandonRun(projectId, sessionId, error);
    }
    await _persist();
  }

  /// Si la sesión sumó al menos un mensaje de trabajo desde [since]. Es lo
  /// que separa "terminó sin plan pero trabajó" de "terminó sin nada".
  bool _producedAssistantOutput(
    String projectId,
    String sessionId, {
    required int since,
  }) {
    final project = _projectById(projectId);
    final messages = project == null
        ? null
        : _sessionById(project, sessionId)?.messages;
    if (messages == null) return false;
    return messages
        .skip(since)
        .any((m) => m.role == ChatRole.assistant && m.text.trim().isNotEmpty);
  }

  /// El cierre de la sesión se decide contra el PLAN, no contra los pasos.
  ///
  /// Son dos cosas distintas y la diferencia es justo la que se perdía: el
  /// workflow puede recorrer sus siete pasos enteros y dejar la mitad de lo
  /// acordado sin hacer. "El flujo terminó" no es "la sesión está hecha".
  ///
  /// Con puntos pendientes, quien planificó vuelve UNA vez a verificarlos
  /// contra el código —no contra lo que se dijo en el hilo— y a cerrar lo que
  /// esté hecho. Si después de eso todavía falta algo, la sesión no se da por
  /// terminada.
  Future<void> _closeAgainstPlan(
    String projectId,
    String sessionId,
    Workflow workflow, {
    required int messagesAtStart,
    String? lastHandle,
    String? lastAnswer,
  }) async {
    final plan = planOf(projectId, sessionId);
    final pendientes = plan.where((item) => !item.done).toList();
    if (pendientes.isEmpty) {
      // Plan vacío no es plan cumplido. Una sesión sin plan cierra como
      // siempre SI produjo algo; si el ciclo terminó sin plan y sin un solo
      // mensaje de trabajo, sellarla "terminada" era un éxito falso.
      if (plan.isEmpty &&
          !_producedAssistantOutput(
            projectId,
            sessionId,
            since: messagesAtStart,
          )) {
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.error,
            text:
                'El ciclo terminó sin plan y sin producir nada — la sesión no '
                'se da por terminada.',
            timestamp: DateTime.now(),
          ),
        );
        _finishSession(projectId, sessionId, SessionStatus.failed);
        return;
      }
      _finishSession(projectId, sessionId, SessionStatus.finished);
      return;
    }

    final project = _projectById(projectId);
    if (project == null) return;
    final verificador = _planCloser(project, sessionId, workflow);
    // Sin nadie que pueda verificar, la sesión igual no miente: queda como no
    // terminada, con el plan a la vista mostrando qué falta.
    if (verificador == null) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text:
              'Los pasos terminaron con ${pendientes.length} de ${plan.length} '
              'puntos del plan sin cumplir, y este proyecto no tiene a quién '
              'darle la verificación.',
          timestamp: DateTime.now(),
        ),
      );
      _finishSession(projectId, sessionId, SessionStatus.failed);
      return;
    }

    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.system,
        text:
            'Los ${workflow.steps.length} pasos terminaron, pero quedan '
            '${pendientes.length} de ${plan.length} puntos del plan sin '
            'cumplir. Verifica @${verificador.name} antes de cerrar.',
        timestamp: DateTime.now(),
      ),
    );

    await _runTurn(
      projectId: projectId,
      sessionId: sessionId,
      member: verificador,
      stepIndex: workflow.steps.length - 1,
      instruction: _planCheckPrompt(
        pendientes,
        hasPlanTools:
            project.tuned(verificador).provider != AgentProvider.codex,
        lastHandle: lastHandle,
        lastAnswer: lastAnswer,
      ),
      consultOfProfileId: null,
      turnId: generateUuidV4(),
      depth: 0,
      // Cerrar no es reabrir el trabajo: si el verificador arrastra a los
      // demás, la sesión vuelve a correr entera por la puerta de atrás.
      allowConsults: false,
    );

    final quedan = planOf(projectId, sessionId).where((item) => !item.done);
    if (quedan.isEmpty) {
      _finishSession(projectId, sessionId, SessionStatus.finished);
      return;
    }

    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.error,
        text:
            '$_cycleInvitePrefix. Falta:\n'
            '${quedan.map((item) => '· ${item.text}${item.ownerRole == null ? '' : '  → ${item.ownerRole}'}').join('\n')}\n'
            'Escribí "continuar" —o tocá el botón del plan— para arrancar el '
            'ciclo del próximo punto desde el paso 1.',
        timestamp: DateTime.now(),
      ),
    );
    _finishSession(projectId, sessionId, SessionStatus.failed);
  }

  /// Quién verifica el plan al cerrar: el dueño del PRIMER paso, que es quien
  /// lo escribió. Si ese puesto está vacante, el del último, que es el que
  /// venía de mirar el resultado.
  ///
  /// Entre los candidatos se prefiere uno que NO corra con codex: el
  /// verificador claude tiene las tools del plan de verdad. Un codex
  /// verifica con los bloques ```cumplido, pero solo si no hay alternativa.
  AgentProfile? _planCloser(
    Project project,
    String sessionId,
    Workflow workflow,
  ) {
    final session = _sessionById(project, sessionId);
    final candidatos = [
      for (final step in [workflow.steps.first, workflow.steps.last])
        _memberForRole(project, step.role, session: session),
    ].whereType<AgentProfile>().toList();
    for (final member in candidatos) {
      if (project.tuned(member).provider != AgentProvider.codex) return member;
    }
    return candidatos.firstOrNull;
  }

  /// Walks the workflow's steps in order, one turn each. `ended` es true
  /// cuando ya cerró la sesión él mismo — un rol vacante o un paso fallido
  /// terminan la corrida y el caller no debe sellar "finished" encima.
  /// `lastHandle`/`lastAnswer` son el remate del último paso, para que el
  /// cierre contra el plan reciba lo que quedó dicho — una decisión
  /// pendiente nombrada al final llega sola a la verificación, sin esperar
  /// que el usuario la reenvíe.
  Future<({bool ended, String? lastHandle, String? lastAnswer})> _runSteps(
    String projectId,
    String sessionId,
    Workflow workflow,
    String trimmed,
  ) async {
    // El handoff entre pasos: lo que dejó dicho el anterior viaja al
    // siguiente. El hilo nunca llega al CLI, así que sin esto el paso N no
    // veía NADA del N-1 — solo el plan y el árbol de archivos.
    String? previousHandle;
    String? previousAnswer;

    for (var index = 0; index < workflow.steps.length; index++) {
      if (_stoppedSessionIds.contains(sessionId)) break;

      final step = workflow.steps[index];
      final current = _projectById(projectId);
      if (current == null) break;

      final member = _memberForRole(
        current,
        step.role,
        session: _sessionById(current, sessionId),
      );
      if (member == null) {
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.error,
            text:
                'Ningún agente de este proyecto tiene el rol "${step.role}", '
                'que pide el paso "${step.title}". El flujo se detiene acá.',
            timestamp: DateTime.now(),
            stepIndex: index,
          ),
        );
        _finishSession(projectId, sessionId, SessionStatus.failed);
        await _persist();
        return (ended: true, lastHandle: null, lastAnswer: null);
      }

      _updateSession(
        projectId,
        sessionId,
        (session) => session.copyWith(currentStepIndex: index),
      );

      final outcome = await _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: member,
        stepIndex: index,
        instruction: _stepPrompt(
          step,
          index,
          workflow,
          trimmed,
          previousHandle: previousHandle,
          previousAnswer: previousAnswer,
        ),
        consultOfProfileId: null,
        turnId: generateUuidV4(),
        depth: 0,
      );
      if (_stoppedSessionIds.contains(sessionId)) break;

      // Un paso que falló corta el ciclo. Seguir marchando era N pasos
      // fallando en cadena sobre un turno muerto, más una verificación que
      // también fallaba — puro costo sin trabajo.
      if (!outcome.ok) {
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.error,
            text:
                'El paso ${index + 1} ("${step.title}") no produjo resultado; '
                'el ciclo se corta acá en vez de arrastrar el error por los '
                'pasos que quedan. Corregí la causa y mandá un mensaje para '
                'retomar.',
            timestamp: DateTime.now(),
            stepIndex: index,
          ),
        );
        _finishSession(projectId, sessionId, SessionStatus.failed);
        await _persist();
        return (ended: true, lastHandle: null, lastAnswer: null);
      }

      previousHandle = member.name;
      previousAnswer = outcome.answer;
    }
    return (
      ended: false,
      lastHandle: previousHandle,
      lastAnswer: previousAnswer,
    );
  }

  /// A step that blows up must still end the run. Without this the loop
  /// escapes with `isRunning` left on and the channel is locked for good.
  Future<void> _abandonRun(
    String projectId,
    String sessionId,
    Object error,
  ) async {
    Log.e('Workflow run failed', error: error);
    _runningSessions.remove(sessionId);
    _stoppedSessionIds.remove(sessionId);
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.error,
        text: 'El flujo se cortó por un error inesperado: $error',
        timestamp: DateTime.now(),
      ),
    );
    _finishSession(projectId, sessionId, SessionStatus.failed);
    await _persist();
  }

  /// What the composer calls. Everything it does happens **inside the session
  /// that is already open** — it never creates one. The first message of a
  /// session kicks off the workflow; every message after that is a follow-up to
  /// the agent that is holding the work.
  Future<void> sendToChannel(String projectId, String text) async {
    final trimmedForInsights = text.trim();
    if (trimmedForInsights.isNotEmpty) {
      // Zero-token recurrence detector — never in the send critical path.
      unawaited(
        PromptInsightsService.instance.notifier.record(trimmedForInsights),
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final project = _projectById(projectId);
    if (project == null) return;

    final session = project.activeSession;
    if (session == null) return;
    if (session.isRunning) return;

    final started = session.messages.any(
      (message) => message.role == ChatRole.assistant,
    );
    if (!started) {
      // El título se deduce del primer pedido SOLO si sigue siendo el de
      // fábrica: si el usuario ya lo puso a mano, el suyo manda.
      _updateSession(
        projectId,
        session.id,
        (open) => open.title == kDefaultSessionTitle
            ? open.copyWith(title: _titleFor(trimmed))
            : open,
      );
      _appendMessage(
        projectId,
        session.id,
        ChatMessage(
          role: ChatRole.user,
          text: trimmed,
          timestamp: DateTime.now(),
        ),
      );
      return _runWorkflow(projectId, session.id, trimmed);
    }

    // "Continuá" con puntos pendientes no es un mensaje para el que habló
    // último: es arrancar el ciclo del siguiente punto, desde el paso 1. Sin
    // esto el flujo termina y no hay forma de volver a planificar — que es
    // exactamente donde se trababa.
    final invited =
        session.messages.lastOrNull?.text.startsWith(_cycleInvitePrefix) ??
        false;
    if (_looksLikeContinue(trimmed, invitedToContinue: invited) &&
        _nextPendingItem(session) != null) {
      _appendMessage(
        projectId,
        session.id,
        ChatMessage(
          role: ChatRole.user,
          text: trimmed,
          timestamp: DateTime.now(),
        ),
      );
      return continueWithNextPlanItem(projectId, session.id);
    }

    final member = _followUpOwner(project, session);
    if (member == null) {
      _appendMessage(
        projectId,
        session.id,
        ChatMessage(
          role: ChatRole.error,
          text:
              'Ningún agente de este proyecto puede tomar este mensaje. '
              'Revisá que los roles del workflow tengan agentes asignados.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    _appendMessage(
      projectId,
      session.id,
      ChatMessage(
        role: ChatRole.user,
        text: trimmed,
        timestamp: DateTime.now(),
      ),
    );
    await _runMemberTurn(
      projectId: projectId,
      sessionId: session.id,
      member: member,
      stepIndex: session.currentStepIndex,
      instruction: trimmed,
    );
  }

  /// El próximo punto del plan sin cumplir, o null si no queda ninguno.
  SessionPlanItem? _nextPendingItem(Session session) =>
      session.plan.where((item) => !item.done).firstOrNull;

  /// Un "seguí" pelado: una orden de continuar y nada más.
  ///
  /// Se exige que sea corto a propósito. "Continuá pero primero mirá el
  /// endpoint X" no es esto: ahí el usuario está diciendo algo, y va como
  /// mensaje al que tiene la palabra, no como arranque de un ciclo nuevo.
  ///
  /// Y hay dos niveles. "Continuar" —la palabra que enseñan el botón y el
  /// mensaje de cierre— vale siempre, igual que un "seguí" que nombra el
  /// plan explícito. Pero un "dale" o un "sigue" pelados solo cuentan cuando
  /// [invitedToContinue]: si lo último del hilo no es la invitación del
  /// cierre, "dale" es una respuesta a quien tiene la palabra (una pregunta
  /// del agente, por ejemplo), no la orden de arrancar un ciclo entero.
  static bool _looksLikeContinue(
    String text, {
    required bool invitedToContinue,
  }) {
    if (text.length > 40) return false;
    final normalized = normalizeForMatch(
      text,
    ).replaceAll(RegExp(r'[^a-z ]'), '').trim();

    final strong = RegExp(
      r'^(continua|continuar|continue|continuemos)'
      r'( con)?( el)?( siguiente)?( punto)?( del plan)?$'
      r'|^(dale|segui|seguir|sigue|next)'
      r'( con)?( el)?( siguiente)? punto( del plan)?$'
      r'|^siguiente punto( del plan)?$',
    );
    if (strong.hasMatch(normalized)) return true;

    if (!invitedToContinue) return false;
    return RegExp(
      r'^(dale|segui|seguir|sigue|siguiente|next|ok|si)$',
    ).hasMatch(normalized);
  }

  /// Arranca OTRO ciclo del workflow, desde el paso 1, para el próximo punto
  /// pendiente del plan.
  ///
  /// Es la pieza que faltaba. El workflow era una sola pasada: con un plan de
  /// siete puntos, el paso 1 planificaba el primero, la implementación hacía
  /// ese, y al llegar al final no había forma de volver a planificar los seis
  /// que quedaban. El implementador pedía charters que solo el paso 1 podía
  /// dar, y el paso 1 ya había pasado — nadie estaba equivocado y la sesión no
  /// avanzaba. Cada punto del plan es ahora una vuelta completa del flujo.
  Future<void> continueWithNextPlanItem(
    String projectId,
    String sessionId,
  ) async {
    final project = _projectById(projectId);
    if (project == null) return;

    final session = _sessionById(project, sessionId);
    if (session == null || session.isRunning) return;

    final item = _nextPendingItem(session);
    if (item == null) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.system,
          text: 'El plan no tiene puntos pendientes.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    final restantes = session.plan.where((entry) => !entry.done).length;
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.system,
        text:
            'CICLO NUEVO del workflow, desde el paso 1, para el punto '
            '"${item.text}"'
            '${item.ownerRole == null ? '' : ' (le toca a ${item.ownerRole})'}. '
            'Quedan $restantes puntos.',
        timestamp: DateTime.now(),
      ),
    );

    await _runWorkflow(
      projectId,
      sessionId,
      _planItemRequest(item, restantes, originalRequest: session.request),
    );
  }

  /// Lo que arranca el ciclo de un punto: el pedido original para no perder
  /// el contexto, y el punto como único trabajo de este ciclo.
  String _planItemRequest(
    SessionPlanItem item,
    int restantes, {
    required String originalRequest,
  }) {
    final original = originalRequest.trim();
    final encabezado = original.isEmpty
        ? ''
        : 'El pedido original de la sesión:\n'
              '${original.length <= 1500 ? original : '${original.substring(0, 1500)}…'}\n\n';
    return '${encabezado}En este ciclo trabajá SOLO este punto pendiente '
        'del plan:\n\n'
        '${item.text}\n\n'
        '${item.ownerRole == null ? '' : 'El plan se lo asignó al puesto "${item.ownerRole}".\n'}'
        'Es UN punto de los $restantes que quedan: hacé ese y nada más. Lo que '
        'ya se hizo en los ciclos anteriores está en el hilo y en el árbol de '
        'trabajo — seguí sobre eso, sin volver a empezar: si esta sesión ya '
        'tiene rama y PR, seguí en los mismos, no abras otros.';
  }

  /// A member hit a tool it is not allowed to use. The CLI runs headless, so
  /// it cannot stop and ask — it just denies and keeps going, often several
  /// times in the same turn. So the session asks *once*, on your behalf, and
  /// remembers who was blocked in order to resume them if you say yes.
  void _handlePermissionDenied({
    required String projectId,
    required String sessionId,
    required AgentProfile member,
    required int stepIndex,
    required PermissionRequest request,
  }) {
    final project = _projectById(projectId);
    if (project == null) return;

    // The sandbox is the project's working directory, which is a setting of
    // the project, not something to grant per turn. Say so plainly instead of
    // offering a button that would not fix it.
    if (request.isSandboxRestriction) {
      final alreadySaid =
          _sessionById(project, sessionId)?.messages.any(
            (message) => message.text.contains('fuera del directorio'),
          ) ??
          false;
      if (alreadySaid) return;

      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text:
              '${member.name} intentó abrir algo fuera del directorio de '
              'trabajo del proyecto. Cambiá el directorio del proyecto si '
              'necesita llegar ahí.',
          timestamp: DateTime.now(),
          stepIndex: stepIndex,
        ),
      );
      return;
    }

    // Asking twice for the same tool in the same session is noise — that is the
    // wall of identical denials this replaces.
    final pending = _sessionById(project, sessionId)?.pendingPermission;
    if (pending?.toolName == request.toolName) return;

    _permissionBlockedProfileBySession[sessionId] = member.id;
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(pendingPermission: request),
    );
  }

  /// Your answer to the question above. Granting widens the permission for
  /// every agent — it is an app-level setting, not a per-agent one — and then
  /// puts the blocked member back to work where it stopped.
  Future<void> respondToSessionPermission(
    String projectId,
    String sessionId, {
    required bool grant,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return;
    final session = _sessionById(project, sessionId);
    final request = session?.pendingPermission;
    if (session == null || request == null) return;

    final blockedProfileId = _permissionBlockedProfileBySession.remove(
      sessionId,
    );
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(clearPendingPermission: true),
    );
    if (!grant) return;

    SettingsService.instance.notifier.setExtraToolEnabled(
      request.toolName,
      true,
    );

    final member = membersOf(
      project,
      session: session,
    ).where((profile) => profile.id == blockedProfileId).firstOrNull;
    if (member == null) return;

    await _runMemberTurn(
      projectId: projectId,
      sessionId: sessionId,
      member: member,
      stepIndex: session.currentStepIndex,
      instruction:
          'Ya tenés permiso para usar ${request.toolName}. Retomá lo que '
          'estabas haciendo desde donde te quedaste.',
    );
  }

  /// Sends a line-scoped question to the member that wrote the file, so the
  /// project answers about code the same way a 1:1 chat does.
  Future<void> askAboutLine(
    String projectId, {
    required String profileId,
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) async {
    final prompt =
        'Sobre el archivo $filePath, línea $lineNumber:\n\n'
        '```\n$lineContent\n```\n\n$question';

    final project = _projectById(projectId);
    if (project == null) return;
    final session = project.activeSession;
    if (session == null) return;
    final member = membersOf(
      project,
      session: session,
    ).where((m) => m.id == profileId).firstOrNull;
    if (member == null) return;

    _appendMessage(
      projectId,
      session.id,
      ChatMessage(
        role: ChatRole.user,
        text: 'Sobre `${filePath.split('/').last}:$lineNumber` — $question',
        timestamp: DateTime.now(),
      ),
    );
    await _runMemberTurn(
      projectId: projectId,
      sessionId: session.id,
      member: member,
      stepIndex: session.currentStepIndex,
      instruction: prompt,
    );
  }

  /// Tells the member that owns a file that the user edited it by hand, so the
  /// next turn works from what is actually on disk.
  Future<void> recordManualEdit(
    String projectId, {
    required String profileId,
    required String filePath,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return;
    final session = project.activeSession;
    if (session == null) return;
    final member = membersOf(
      project,
      session: session,
    ).where((m) => m.id == profileId).firstOrNull;
    if (member == null) return;

    _appendMessage(
      projectId,
      session.id,
      ChatMessage(
        role: ChatRole.user,
        text: 'Edité a mano `${filePath.split('/').last}`.',
        timestamp: DateTime.now(),
      ),
    );
    await _runMemberTurn(
      projectId: projectId,
      sessionId: session.id,
      member: member,
      stepIndex: session.currentStepIndex,
      instruction:
          'El usuario acaba de editar a mano el archivo $filePath. Leelo de '
          'nuevo antes de seguir y tené en cuenta ese cambio.',
    );
  }

  /// One-off turn outside the step loop: marks the session busy, runs the member,
  /// and settles the session again.
  Future<void> _runMemberTurn({
    required String projectId,
    required String sessionId,
    required AgentProfile member,
    required int stepIndex,
    required String instruction,
  }) async {
    _stoppedSessionIds.remove(sessionId);
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(isRunning: true),
    );
    await _persist();

    // `finally`, because a turn that throws must still hand the channel back.
    // Otherwise `isRunning` stays true, the composer stays locked, and the
    // only way out is deleting the session.
    try {
      await _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: member,
        stepIndex: stepIndex,
        instruction: instruction,
        consultOfProfileId: null,
        turnId: generateUuidV4(),
        depth: 0,
      );
    } finally {
      _runningSessions.remove(sessionId);
      _stoppedSessionIds.remove(sessionId);
      _purgeConsultLedgerIfIdle();
      _updateSession(
        projectId,
        sessionId,
        (session) => session.copyWith(isRunning: false, clearLiveTurn: true),
      );
      await _persist();
    }
  }

  /// Who takes a follow-up message inside an already-started session. Prefers the
  /// agent that owns the current step; once the workflow has run out of steps
  /// it falls back to whoever spoke last, and finally to any member — a
  /// question inside a session must always land on somebody, never bounce.
  AgentProfile? _followUpOwner(Project project, Session session) {
    final workflow = activeWorkflowOf(project);
    if (workflow != null && session.currentStepIndex < workflow.steps.length) {
      final owner = _memberForRole(
        project,
        workflow.steps[session.currentStepIndex].role,
        session: session,
      );
      if (owner != null) return owner;
    }

    final members = membersOf(project, session: session);
    for (var i = session.messages.length - 1; i >= 0; i--) {
      final authorId = session.messages[i].authorProfileId;
      if (authorId == null) continue;
      final author = members.where((m) => m.id == authorId).firstOrNull;
      if (author != null) return author;
    }
    return members.firstOrNull;
  }

  /// Fills in the working directory of a project that arrived without one
  /// (catalog import strips paths on purpose — they're machine-local).
  void setProjectWorkingDirectory(String id, String path) {
    _updateProject(id, (project) => project.copyWith(workingDirectory: path));
    unawaited(_persist());
  }

  // ── ejecución de un turno ───────────────────────────────────────────

  /// Runs one CLI turn for [member] and folds its events into the session thread.
  /// After the turn, any `@handle` it wrote is resolved into a consultation
  /// turn, bounded by [_maxConsultDepth] so a chain can't run away.
  ///
  /// Devuelve cómo terminó: [TurnOutcome.ok] es falso cuando el CLI falló,
  /// reportó error o no produjo texto — y con eso el caller decide si el
  /// ciclo sigue o se corta, en vez de marchar a ciegas.
  Future<TurnOutcome> _runTurn({
    required String projectId,
    required String sessionId,
    required AgentProfile member,
    required int stepIndex,
    required String instruction,
    required String? consultOfProfileId,
    required String turnId,
    required int depth,
    bool allowConsults = true,
    bool retriedWithoutSession = false,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return (ok: false, answer: '');
    if (_stoppedSessionIds.contains(sessionId)) return (ok: false, answer: '');

    final cliSessionId = _sessionById(
      project,
      sessionId,
    )?.cliSessionsByProfileId[member.id];
    final collector = FileEditCollector(
      workingDirectory: project.workingDirectory,
    );
    final reasoning = StringBuffer();
    final answer = StringBuffer();
    var turnFailed = false;
    var sessionConfirmed = false;
    var failureMessage = '';

    // El mapa de las bases se arma leyendo el disco: si el catálogo todavía
    // no cargó, el turno saldría sin saber que existen. Acá sí se puede
    // esperar — `_turnSystemPrompt` es síncrono a propósito.
    await KnowledgeService.instance.notifier.ready;

    // The member's assigned executable tools travel as a per-turn MCP
    // config — the loopback server runs in the main isolate, and the CLI
    // subprocess reaches it over 127.0.0.1 regardless of which isolate
    // spawned it.
    // El agente es global, pero con qué motor corre es decisión de ESTA
    // proyecto: mismo `@flutter-expert` en Sonnet acá y en Opus allá. Se
    // resuelve una sola vez y de acá en más manda `engine` — incluido el
    // proveedor, porque cambiarlo cambia qué superficie tiene el turno.
    final engine = project.tuned(member);

    // Codex has no per-turn tools/MCP surface — those stay empty for it.
    final isCodex = engine.provider == AgentProvider.codex;
    final memberTools = isCodex
        ? const <Tool>[]
        : ToolsService.instance.notifier.toolsByNames(member.tools);
    final toolsEntry = memberTools.isEmpty
        ? null
        : UserToolsMcpServer.mcpServerEntryFor(
            member.id,
            workingDirectory: project.workingDirectory,
          );
    final externalServers = isCodex
        ? const <McpServerConfig>[]
        : McpServersService.instance.notifier.serversByNames(member.mcpServers);
    final externalSecretValues = SecretsService.instance.notifier.valuesFor([
      for (final server in externalServers) ...server.secretNames,
    ]);
    // El plan de la sesión va en los turnos de proyecto sin depender de que el
    // perfil tenga tools asignadas: es del canal, no del agente. Pero NO en
    // un turno de consulta — el consultado lo ve como contexto y lo marca
    // quien ejecuta el paso; darle las tools de verdad dejaba que reescriba
    // el plan de otro con una línea de prosa como único freno.
    final planEntry = (isCodex || consultOfProfileId != null)
        ? null
        : SessionPlanMcpServer.mcpServerEntryFor(
            projectId: projectId,
            sessionId: sessionId,
            profileId: member.id,
          );
    // El roadmap del PROYECTO, distinto del plan de la sesión: uno dura meses
    // y vive en el repo, el otro dura una tarde y vive en el canal. Solo
    // aparece si el proyecto tiene carpeta TASKS/ — sin eso, tres tools que
    // no aplican.
    final roadmapEntry = (isCodex || consultOfProfileId != null)
        ? null
        : RoadmapMcpServer.mcpServerEntryFor(
            projectId: projectId,
            profileId: member.id,
            workingDirectory: project.workingDirectory,
          );
    final mcpServers = <String, dynamic>{
      kUserToolsMcpServerKey: ?toolsEntry,
      kSessionPlanMcpServerKey: ?planEntry,
      kRoadmapMcpServerKey: ?roadmapEntry,
      for (final server in externalServers)
        server.name: server.toMcpServerEntry(externalSecretValues),
    };

    // La ENTREGA (PR en draft) solo aplica donde hay repo.
    final usesGit = Directory('${project.workingDirectory}/.git').existsSync();

    // Codex recibe el system prompt solo en el PRIMER turno de su sesión: en
    // turnos resumidos el estado del plan quedaría congelado en el turno 1.
    // El estado vivo viaja antepuesto al pedido, que sí llega siempre.
    final effectiveInstruction = (isCodex && cliSessionId != null)
        ? [
            _planSection(
              _sessionById(project, sessionId),
              isConsult: consultOfProfileId != null,
              hasPlanTools: false,
            ),
            instruction,
          ].where((part) => part.isNotEmpty).join('\n\n')
        : instruction;

    // Los guardarraíles del turno. Se resuelven de este lado: el isolate del
    // session runner no alcanza ni el catálogo ni los secrets, así que lo que
    // cruza son archivos ya renderizados.
    final turnHooks = await _resolveTurnHooks(project, engine);
    for (final note in turnHooks.notes) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.system,
          text: note,
          timestamp: DateTime.now(),
        ),
      );
    }

    final run = await TaskRunner.run(
      TaskRunSpec(
        prompt: effectiveInstruction,
        workingDirectory: project.workingDirectory,
        model: engine.model,
        fullFileSystemAccess: false,
        effort: engine.effort,
        extraAllowedTools: [
          // Un proyecto que no mantenés es de SOLO LECTURA, y eso se hace
          // sacándole las tools que escriben — no pidiéndoselo por prompt.
          // Un pedido se puede ignorar; una tool que no está, no.
          //
          // Las tools propias del usuario sí siguen: son suyas, y marcar el
          // proyecto como ajeno no dice nada sobre ellas.
          if (project.maintained)
            ...SettingsService.instance.notifier.data.extraAllowedTools,
          if (planEntry != null) ...kSessionPlanMcpToolNames,
          if (roadmapEntry != null) ...kRoadmapMcpToolNames,
          if (toolsEntry != null)
            ...memberTools.map(
              (tool) => '$kUserToolsMcpToolPrefix${tool.name}',
            ),
          ...externalServers.map((server) => 'mcp__${server.name}'),
        ],
        sessionId: cliSessionId,
        additionalSystemPrompt: _turnSystemPrompt(
          project,
          member,
          session: _sessionById(project, sessionId),
          isConsult: consultOfProfileId != null,
          hasPlanTools: planEntry != null,
          usesGit: usesGit,
        ),
        mcpConfig: mcpServers.isEmpty
            ? null
            : jsonEncode({'mcpServers': mcpServers}),
        hooksSettings: turnHooks.claudeSettings,
        hooksConfig: turnHooks.codexConfig,
        hookFiles: turnHooks.files,
        provider: engine.provider.alias,
      ),
    );
    _runningSessions[sessionId] = run;
    // The channel is shared, so the live strip has to say *who* is working.
    _updateSession(
      projectId,
      sessionId,
      (session) =>
          session.copyWith(liveTurn: SessionLiveTurn(profileId: member.id)),
    );

    await for (final event in run.events) {
      if (_stoppedSessionIds.contains(sessionId)) break;

      switch (event) {
        case TaskSessionStarted(sessionId: final id):
          sessionConfirmed = true;
          _updateSession(projectId, sessionId, (session) {
            final sessions = Map<String, String>.from(
              session.cliSessionsByProfileId,
            );
            sessions[member.id] = id;
            return session.copyWith(cliSessionsByProfileId: sessions);
          });

        case TaskAssistantText(text: final chunk):
          answer.write(chunk);
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.assistant,
              text: chunk,
              timestamp: DateTime.now(),
              reasoning: reasoning.isEmpty ? null : reasoning.toString(),
              fileEdits: await collector.collect(),
              authorProfileId: member.id,
              stepIndex: stepIndex,
              consultOfProfileId: consultOfProfileId,
            ),
          );
          reasoning.clear();
          _updateLiveTurn(
            projectId,
            sessionId,
            (turn) => turn.copyWith(
              clearReasoning: true,
              clearActivity: true,
              phase: TurnPhase.writing,
            ),
          );

        case TaskToolUse(name: final name, input: final input):
          _updateLiveTurn(
            projectId,
            sessionId,
            (turn) => turn.copyWith(
              activity: AgentToolActivity.fromToolUse(name, input),
              phase: TurnPhase.working,
            ),
          );
          final path = FileEditCollector.filePathFor(name, input);
          if (path != null) await collector.noteBeforeEdit(path);

        case TaskReasoningChunk(text: final chunk):
          reasoning.write(chunk);
          _updateLiveTurn(
            projectId,
            sessionId,
            (turn) => turn.copyWith(
              reasoning: reasoning.toString(),
              phase: TurnPhase.thinking,
              clearActivity: true,
            ),
          );

        case TaskTurnCompleted(
          isError: final isError,
          costUsd: final costUsd,
          durationMs: final durationMs,
        ):
          if (costUsd > 0) {
            _updateSession(projectId, sessionId, (session) {
              final costs = Map<String, double>.from(session.costByProfileId);
              costs[member.id] = (costs[member.id] ?? 0) + costUsd;
              return session.copyWith(
                costUsd: session.costUsd + costUsd,
                costByProfileId: costs,
              );
            });
          }
          if (isError) {
            turnFailed = true;
            _appendMessage(
              projectId,
              sessionId,
              ChatMessage(
                role: ChatRole.error,
                text: 'claude reportó un error en el turno de ${member.name}.',
                timestamp: DateTime.now(),
                stepIndex: stepIndex,
              ),
            );
          } else {
            _annotateLastMessage(
              projectId,
              sessionId,
              costUsd: costUsd,
              durationMs: durationMs,
            );
          }

        case TaskPermissionDenied(
          toolName: final toolName,
          message: final message,
        ):
          _handlePermissionDenied(
            projectId: projectId,
            sessionId: sessionId,
            member: member,
            stepIndex: stepIndex,
            request: PermissionRequest(toolName: toolName, message: message),
          );

        case TaskContextUsage(
          usedTokens: final usedTokens,
          contextWindowTokens: final windowTokens,
        ):
          _updateSession(
            projectId,
            sessionId,
            (session) => session.copyWith(
              contextUsedTokens: usedTokens,
              contextWindowTokens: windowTokens,
            ),
          );

        case TaskFailure(message: final message):
          turnFailed = true;
          failureMessage = message;
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.error,
              text: message,
              timestamp: DateTime.now(),
              stepIndex: stepIndex,
            ),
          );
      }
    }

    // Una sesión persistida que el CLI ya no conoce rompía al miembro para
    // siempre en esta sesión: cada turno futuro reintentaba el mismo --resume
    // y fallaba igual, sin que nadie limpiara el id. Si el fallo huele a
    // sesión —pedimos resume, nunca abrió una, y el error habla de eso—, se
    // limpia y se reintenta UNA vez de cero.
    final looksLikeDeadSession =
        cliSessionId != null &&
        !sessionConfirmed &&
        (failureMessage.toLowerCase().contains('session') ||
            failureMessage.toLowerCase().contains('conversation'));
    if (turnFailed &&
        looksLikeDeadSession &&
        !retriedWithoutSession &&
        !_stoppedSessionIds.contains(sessionId)) {
      _updateSession(projectId, sessionId, (session) {
        final sessions = Map<String, String>.from(
          session.cliSessionsByProfileId,
        )..remove(member.id);
        return session.copyWith(cliSessionsByProfileId: sessions);
      });
      return _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: member,
        stepIndex: stepIndex,
        instruction: instruction,
        consultOfProfileId: consultOfProfileId,
        turnId: turnId,
        depth: depth,
        allowConsults: allowConsults,
        retriedWithoutSession: true,
      );
    }

    _runningSessions.remove(sessionId);
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(clearLiveTurn: true),
    );
    await _persist();

    // Before the consult pass, so a specialist declared in this answer is a
    // real member by the time the same answer mentions its @handle.
    await _registerDeclaredAgents(
      projectId: projectId,
      sessionId: sessionId,
      author: member,
      text: answer.toString(),
      stepIndex: stepIndex,
    );

    // El espejo de las tools del plan para codex: sin esto, un plan cuyo
    // paso 1 cae en un miembro codex no existía nunca, y el cierre sellaba
    // "terminada" una sesión sin contrato.
    if (isCodex) {
      _applyDeclaredPlanBlocks(
        projectId: projectId,
        sessionId: sessionId,
        author: member,
        text: answer.toString(),
      );
    }

    final outcome = (
      ok: !turnFailed && answer.toString().trim().isNotEmpty,
      answer: answer.toString(),
    );

    if (allowConsults && depth < _maxConsultDepth) {
      await _resolveConsultations(
        projectId: projectId,
        sessionId: sessionId,
        asker: member,
        stepIndex: stepIndex,
        text: answer.toString(),
        turnId: turnId,
        depth: depth,
      );
    } else {
      _noteUndeliverableMentions(
        projectId: projectId,
        sessionId: sessionId,
        author: member,
        text: answer.toString(),
      );
    }
    return outcome;
  }

  /// Un turno que no puede abrir consultas pero termina mencionando a un
  /// compañero deja una pregunta colgada que NADIE va a contestar — y el
  /// usuario esperando una respuesta que no llega. Se dice en el momento,
  /// con la salida real: el cierre contra el plan o el próximo ciclo.
  void _noteUndeliverableMentions({
    required String projectId,
    required String sessionId,
    required AgentProfile author,
    required String text,
  }) {
    final project = _projectById(projectId);
    if (project == null) return;
    final members = membersOf(
      project,
      session: _sessionById(project, sessionId),
    );
    final mentioned = <String>{};
    for (final match in _mentionPattern.allMatches(stripCodeSpans(text))) {
      final handle = match.group(1);
      if (handle == null || handle == author.name) continue;
      if (members.any((member) => member.name == handle)) {
        mentioned.add(handle);
      }
    }
    if (mentioned.isEmpty) return;
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.system,
        text:
            'La mención a ${mentioned.map((handle) => '@$handle').join(', ')} '
            'no dispara un turno acá: este turno no puede abrir consultas. '
            'Lo que quedó pendiente lo toma la verificación del cierre o el '
            'próximo ciclo — o respondelo vos con un mensaje.',
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Registers every agent [author] declared in [text] and adds it to the
  /// project, so the specialist it asked for exists for real — with its specs
  /// visible, its creator recorded, and a line in the thread saying so —
  /// instead of running as a subagent nobody can inspect.
  Future<void> _registerDeclaredAgents({
    required String projectId,
    required String sessionId,
    required AgentProfile author,
    required String text,
    required int stepIndex,
  }) async {
    for (final fields in parseFencedBlocks(
      text,
      tag: 'agente',
      keys: _agentDeclarationKeys,
    )) {
      final handle = fields['handle'];
      if (handle == null || handle.isEmpty) continue;

      // Reserved for the built-in system assistant. Checked here, not just
      // at profile-creation time: `keelai` is always already registered, so
      // this loop would otherwise take the "reuse" branch below and quietly
      // hand the declaring member a companion that isn't what they asked for.
      if (handle == kKeelAiHandle) {
        Log.w('${author.name} intentó declarar el handle reservado "$handle"');
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.error,
            text:
                '${author.name} quiso declarar "$handle" pero ese nombre '
                'está reservado.',
            timestamp: DateTime.now(),
            stepIndex: stepIndex,
          ),
        );
        continue;
      }

      final profiles = AgentProfilesService.instance.notifier;
      final existing = profiles.data.profiles
          .where((profile) => profile.name == handle)
          .firstOrNull;

      // An agent that already exists is reused, never duplicated — that is
      // the whole point of registering agents globally.
      var profileId = existing?.id;
      if (existing == null) {
        final error = profiles.createProfile(
          name: handle,
          role: fields['rol'] ?? handle,
          systemPrompt: [
            if (fields['proposito'] != null) fields['proposito']!,
            if (fields['instrucciones'] != null) fields['instrucciones']!,
          ].join('\n\n'),
          skills: const [],
          rules: const [],
          model: author.model,
          effort: author.effort,
          createdByProfileId: author.id,
        );
        if (error != null) {
          Log.w('${author.name} declaró un agente inválido "$handle": $error');
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.error,
              text:
                  '${author.name} quiso crear el agente "$handle" pero no se '
                  'pudo registrar: $error',
              timestamp: DateTime.now(),
              stepIndex: stepIndex,
            ),
          );
          continue;
        }
        profileId = profiles.data.profiles
            .where((profile) => profile.name == handle)
            .firstOrNull
            ?.id;
      }

      if (profileId == null) continue;
      final registeredId = profileId;
      // Scoped to THIS session, not the project: a specialist an agent pulls in
      // mid-conversation exists for that conversation. Making it a standing
      // member is the user's call, from the project form.
      addAgentToSession(projectId, sessionId, registeredId);

      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.assistant,
          text: existing == null
              ? '${author.name} incorporó a **@$handle** '
                    '(${fields['rol'] ?? handle}) a ESTA sesión.'
                    '${fields['proposito'] == null ? '' : '\n\n${fields['proposito']}'}'
              : '${author.name} sumó a **@$handle**, que ya estaba '
                    'registrado, a esta sesión.',
          timestamp: DateTime.now(),
          authorProfileId: author.id,
          stepIndex: stepIndex,
        ),
      );
    }
    await _persist();
  }

  /// Aplica los bloques ```plan y ```cumplido que [author] —un miembro
  /// codex— dejó en [text]. Es el espejo de `set_session_plan` y
  /// `complete_plan_items` para el proveedor que no puede llamar tools MCP.
  void _applyDeclaredPlanBlocks({
    required String projectId,
    required String sessionId,
    required AgentProfile author,
    required String text,
  }) {
    List<String> lineasDe(Map<String, String> fields) =>
        (fields['puntos'] ?? '')
            .split('\n')
            .map((line) => line.trim().replaceFirst(RegExp(r'^[-*]\s+'), ''))
            .where((line) => line.isNotEmpty)
            .toList();

    for (final fields in parseFencedBlocks(
      text,
      tag: 'plan',
      keys: _planBlockKeys,
    )) {
      final lineas = lineasDe(fields);
      if (lineas.isEmpty) continue;
      setSessionPlan(projectId, sessionId, [
        for (final linea in lineas) _planEntryFromLine(linea),
      ]);
    }

    for (final fields in parseFencedBlocks(
      text,
      tag: 'cumplido',
      keys: _planBlockKeys,
    )) {
      final lineas = lineasDe(fields);
      if (lineas.isEmpty) continue;
      completePlanItems(
        projectId,
        sessionId,
        items: lineas,
        byProfileId: author.id,
      );
    }
  }

  /// `texto | puesto`. El corte es el ÚLTIMO pipe, por si el texto lleva
  /// pipes propios; sin pipe, el punto queda sin puesto.
  static PlanEntry _planEntryFromLine(String line) {
    final cut = line.lastIndexOf('|');
    if (cut == -1) return (text: line, ownerRole: null);
    final owner = line.substring(cut + 1).trim();
    return (
      text: line.substring(0, cut).trim(),
      ownerRole: owner.isEmpty ? null : owner,
    );
  }

  /// Turns every `@handle` [asker] wrote into a turn for that member, then
  /// hands the answer back to [asker] so it can continue its own step.
  Future<void> _resolveConsultations({
    required String projectId,
    required String sessionId,
    required AgentProfile asker,
    required int stepIndex,
    required String text,
    required String turnId,
    required int depth,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return;

    final members = membersOf(
      project,
      session: _sessionById(project, sessionId),
    );
    final workflow = activeWorkflowOf(project);
    final asked = <String>{};

    // Sobre el texto SIN código: un @handle dentro de un diff o de un
    // ejemplo es texto, no una mención — y disparaba turnos reales.
    for (final match in _mentionPattern.allMatches(stripCodeSpans(text))) {
      if (_stoppedSessionIds.contains(sessionId)) return;

      final handle = match.group(1);
      if (handle == null || handle == asker.name) continue;
      if (!asked.add(handle)) continue;

      final target = members.where((m) => m.name == handle).firstOrNull;
      if (target == null) {
        // Descartarla en silencio es lo que hace que el que mencionó quede
        // esperando una respuesta que no va a llegar, y que el canal discuta
        // si ese compañero existe. Queda dicho, una vez por handle.
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.system,
            text:
                '@$handle no es miembro de este proyecto, así que esa '
                'mención no llegó a nadie. Miembros: '
                '${members.map((m) => '@${m.name}').join(', ')}.',
            timestamp: DateTime.now(),
          ),
        );
        continue;
      }

      // Presupuesto del turno raíz. La profundidad no acota el ancho: sin
      // esto, un turno con varios miembros mencionándose entre sí podía
      // disparar decenas de turnos CLI reales.
      final gastadas = _consultedPairs
          .where((pair) => pair.startsWith('$turnId:'))
          .length;
      if (gastadas >= _maxConsultsPerRootTurn) {
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.system,
            text:
                'Se alcanzó el límite de $_maxConsultsPerRootTurn consultas '
                'de este turno; las menciones restantes no disparan turnos.',
            timestamp: DateTime.now(),
          ),
        );
        break;
      }

      // El par inverso no rebota: si A ya le consultó a B en este turno, la
      // mención de B a A es la respuesta volviendo — vuelve sola por la
      // continuación, no hace falta otro turno. A→B→A muere acá.
      if (_consultedPairs.contains('$turnId:${target.id}>${asker.id}')) {
        continue;
      }

      // One consult per pair per turn — see [_consultedPairs].
      final pair = '$turnId:${asker.id}>${target.id}';
      if (!_consultedPairs.add(pair)) continue;

      // Los pasos del consultado, con la MISMA resolución rol/handle que usa
      // el flujo para asignarlos — el consultado ve exactamente los que le
      // van a tocar de verdad.
      final targetSteps = <int>[
        if (workflow != null)
          for (var i = 0; i < workflow.steps.length; i++)
            if (_memberForRole(
                  project,
                  workflow.steps[i].role,
                  session: _sessionById(project, sessionId),
                )?.id ==
                target.id)
              i,
      ];

      final consulta = await _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: target,
        stepIndex: stepIndex,
        instruction: _consultPrompt(
          asker,
          _consultExcerpt(text, handle),
          stepIndex: stepIndex,
          workflow: workflow,
          targetSteps: targetSteps,
        ),
        consultOfProfileId: asker.id,
        turnId: turnId,
        depth: depth + 1,
      );
      if (_stoppedSessionIds.contains(sessionId)) return;

      // La respuesta es LO QUE DIJO el consultado — no el último mensaje del
      // hilo, que podía ser un error o un aviso de sistema presentado como
      // "@target respondió". Sin respuesta usable, el que preguntó sigue sin
      // ella y se le dice, en vez de gastarle un turno con basura.
      if (!consulta.ok || consulta.answer.trim().isEmpty) {
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.system,
            text:
                'La consulta a @${target.name} no devolvió respuesta; '
                '@${asker.name} sigue sin ella.',
            timestamp: DateTime.now(),
          ),
        );
        continue;
      }

      // The asker's continuation must NOT open new consults. Otherwise a
      // courteous sign-off that names the other agent ("quedo a la espera de
      // @revision") is read as a fresh question, and the two of them
      // ping-pong confirmations at real cost.
      await _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: asker,
        stepIndex: stepIndex,
        instruction: _consultAnswerPrompt(target, consulta.answer),
        consultOfProfileId: null,
        turnId: turnId,
        depth: depth + 1,
        allowConsults: false,
      );
    }
  }

  // ── prompts ─────────────────────────────────────────────────────────

  String _stepPrompt(
    WorkflowStep step,
    int index,
    Workflow workflow,
    String request, {
    String? previousHandle,
    String? previousAnswer,
  }) {
    final handoff =
        (previousHandle == null || (previousAnswer ?? '').trim().isEmpty)
        ? ''
        : 'Lo que dejó dicho @$previousHandle al cerrar el paso $index:\n'
              '${_handoffExcerpt(previousAnswer!)}\n\n';
    return 'Lo que pidió el usuario en este canal:\n$request\n\n'
        '${handoff}Estás ejecutando el paso ${index + 1} de '
        '${workflow.steps.length} '
        'del flujo "${workflow.name}": ${step.title}.\n'
        '${step.instruction}\n\n'
        'Hacé únicamente lo que corresponde a este paso; los demás pasos los '
        'ejecutan tus compañeros. Cerrá tu turno diciendo en dos líneas qué '
        'dejás listo y qué encontraste — eso es lo que recibe el paso '
        'siguiente.';
  }

  /// El texto del paso anterior, recortado para el handoff: el remate —donde
  /// vive el resumen de cierre— pesa más que el arranque.
  static String _handoffExcerpt(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 2000) return trimmed;
    return '${trimmed.substring(0, 500)}\n…\n'
        '${trimmed.substring(trimmed.length - 1500)}';
  }

  /// Lo que recibe quien cierra la sesión con puntos del plan sin cumplir.
  /// Lleva el remate del último paso: una decisión pendiente nombrada al
  /// final del ciclo tiene que llegarle al verificador sola, no vía usuario.
  String _planCheckPrompt(
    List<SessionPlanItem> pendientes, {
    required bool hasPlanTools,
    String? lastHandle,
    String? lastAnswer,
  }) {
    final remate = (lastHandle == null || (lastAnswer ?? '').trim().isEmpty)
        ? ''
        : 'Lo último que dejó dicho @$lastHandle al cerrar el último paso — '
              'si nombra una decisión que te corresponde, tomala acá y '
              'reflejala en el plan:\n${_handoffExcerpt(lastAnswer!)}\n\n';
    final marcar = hasPlanTools
        ? 'marcalo con `complete_plan_items` copiando su texto'
        : 'marcalo dejando un bloque ```cumplido con `puntos:` y su texto, '
              'un punto por línea';
    final sacar = hasPlanTools
        ? 'sacalo reescribiendo el plan entero con `set_session_plan`'
        : 'sacalo reescribiendo el plan entero con un bloque ```plan';
    return '${remate}Los pasos del workflow terminaron, pero el plan de esta '
        'sesión tiene estos puntos SIN CUMPLIR:\n'
        '${pendientes.map((item) => '- ${item.text}').join('\n')}\n\n'
        'Verificá cada uno CONTRA EL CÓDIGO, no contra lo que se dijo en el '
        'hilo: abrí los archivos y corré lo que haga falta para comprobarlo. '
        'Después, con lo que encontraste:\n'
        '- El que esté hecho, $marcar.\n'
        '- El que ya no corresponda —quedó fuera de alcance, o lo reemplazó '
        'otra decisión— $sacar, y decí en una línea por qué.\n'
        '- El que falte de verdad, dejalo sin marcar y decí a qué puesto le '
        'toca hacerlo. NO lo implementes vos: tu trabajo acá es verificar.\n'
        'Mientras queden puntos sin cumplir, la sesión no se da por terminada.';
  }

  /// Lo que recibe el consultado. Lleva la MECÁNICA de pasos —en qué paso va
  /// el ciclo y cuáles son los suyos— porque sin eso "no te adelantes" y
  /// "resolvelo acá" eran la misma regla imposible: el consultado no tenía
  /// forma de saber si su paso ya pasó.
  String _consultPrompt(
    AgentProfile asker,
    String excerpt, {
    required int stepIndex,
    required Workflow? workflow,
    required List<int> targetSteps,
  }) {
    final buffer = StringBuffer();
    final paso = workflow == null
        ? null
        : stepIndex.clamp(0, workflow.steps.length - 1);
    final donde = workflow == null || paso == null
        ? ''
        : ', durante el paso ${paso + 1} de ${workflow.steps.length} '
              '("${workflow.steps[paso].title}") del flujo '
              '"${workflow.name}"';
    buffer.writeln(
      '@${asker.name} (${asker.role}) te consultó en el canal$donde:',
    );
    buffer.writeln();
    buffer.writeln(excerpt);
    buffer.writeln();
    buffer.writeln(
      'Respondé la consulta desde tu especialidad. Si para responder tenés '
      'que corregir algo en tu área, podés hacerlo. Esto corre como consulta '
      'dentro del paso de @${asker.name}, y en este turno no tenés las tools '
      'del plan: lo que resuelvas, decilo en tu respuesta y lo marca quien '
      'ejecuta el paso.',
    );
    if (workflow == null || paso == null) return buffer.toString().trim();

    if (targetSteps.isEmpty) {
      buffer.writeln(
        'Vos no tenés pasos propios en este flujo: respondé la consulta y '
        'nada más.',
      );
      return buffer.toString().trim();
    }

    final tuyos = targetSteps
        .map((i) => '${i + 1} ("${workflow.steps[i].title}")')
        .join(', ');
    buffer.writeln(
      'Tus pasos en este flujo: $tuyos. El ciclo va por el ${paso + 1}. Con '
      'eso, la regla es mecánica:',
    );
    buffer.writeln(
      '- Si todos tus pasos vienen DESPUÉS del actual, no te adelantes: '
      'respondé solo lo que te preguntaron — tu trabajo llega cuando el '
      'workflow te dé la palabra.',
    );
    buffer.writeln(
      '- Si alguno de tus pasos YA PASÓ en este ciclo y lo que falta es de '
      'ese paso, resolvelo ACÁ: ese paso no va a volver.',
    );
    buffer.writeln(
      '- Si te piden una decisión de tu área, tomala ahora: para eso te '
      'consultaron.',
    );
    return buffer.toString().trim();
  }

  /// Los párrafos de [text] que mencionan a @[handle], más el inmediatamente
  /// anterior de cada uno. La regla de "mínimo contexto" no la puede cumplir
  /// solo el prompt si el código igual manda el turno entero al consultado.
  /// Si no se puede extraer nada, cae al texto completo.
  static String _consultExcerpt(String text, String handle) {
    final paragraphs = text.split('\n\n');
    final keep = <int>{};
    for (var i = 0; i < paragraphs.length; i++) {
      // La mención se busca sin el código: un @handle en un diff no es una
      // consulta, y acá tampoco selecciona párrafos.
      if (stripCodeSpans(paragraphs[i]).contains('@$handle')) {
        if (i > 0) keep.add(i - 1);
        keep.add(i);
      }
    }
    if (keep.isEmpty) return _consultCap(text);
    final excerpt = [
      for (var i = 0; i < paragraphs.length; i++)
        if (keep.contains(i)) paragraphs[i].trim(),
    ].where((paragraph) => paragraph.isNotEmpty).join('\n\n');
    return excerpt.isEmpty ? _consultCap(text) : _consultCap(excerpt);
  }

  static String _consultCap(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 4000) return trimmed;
    return '${trimmed.substring(0, 4000)}…';
  }

  /// El estado real del plan, dentro del turno.
  ///
  /// Nombrar las tools no alcanzaba: `complete_plan_items` pide "el texto
  /// exacto" de puntos que el agente nunca vio, y decidir si escribir el plan
  /// quedaba en manos de que el modelo leyera su paso como "planificar" —el
  /// paso 1 de tdd se llama "Charter" y nadie lo llamó así—. Las dos son
  /// decisiones que la app puede tomar por él.
  String _planSection(
    Session? session, {
    required bool isConsult,
    required bool hasPlanTools,
  }) {
    final plan = session?.plan ?? const <SessionPlanItem>[];

    if (plan.isEmpty) {
      // Un consultado no planifica la sesión de otro: contesta y se va.
      if (isConsult) return '';
      // Codex no tiene las tools del plan: escribe con el bloque fenced.
      final como = hasPlanTools
          ? 'escribilo con `set_session_plan`'
          : 'escribilo dejando en tu respuesta un bloque exactamente así:\n'
                '```plan\n'
                'puntos:\n'
                'Primer punto concreto y verificable | puesto que lo hace\n'
                'Segundo punto\n'
                '```\n'
                'El puesto (tras el último "|") es opcional; no uses "|" '
                'dentro del texto del punto. Escribilo';
      return 'PLAN DE LA SESIÓN: esta sesión todavía no tiene plan, y el plan '
          'es lo que el usuario mira para saber qué falta. ANTES que nada en '
          'este turno, $como: entre 3 y 8 puntos '
          'concretos y verificables que haya que cumplir para darla por '
          'terminada — no las etapas del workflow, que ya se ven aparte. A '
          'cada punto ponele el PUESTO que lo tiene que hacer cuando esté '
          'claro. No importa cómo se llame tu paso: si no hay plan, lo '
          'escribís vos. Después seguí con tu trabajo normal.\n'
          'Cada punto se trabaja después en su propia vuelta del workflow: '
          'un punto es una unidad entregable, no una sesión de media hora.';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'PLAN DE LA SESIÓN (${plan.doneCount} de ${plan.length} cumplidos) — es '
      'lo que el usuario mira para saber qué falta:',
    );
    for (final item in plan) {
      final puesto = item.ownerRole == null ? '' : ' (${item.ownerRole})';
      buffer.writeln('${item.done ? '[x]' : '[ ]'}$puesto ${item.text}');
    }

    if (isConsult) {
      buffer.writeln(
        'Va como contexto: el plan lo marca quien está ejecutando el paso — '
        'en este turno no tenés las tools del plan.',
      );
      return buffer.toString().trim();
    }

    if (hasPlanTools) {
      buffer.writeln(
        'Al cerrar tu turno marcá con `complete_plan_items` los puntos que '
        'efectivamente resolviste, copiando su texto tal como está acá '
        'arriba — la comparación ignora mayúsculas, acentos y puntuación, '
        'pero no adivina: cambiá una palabra y no lo encuentra. Solo esos: '
        'marcar de más deja al usuario ciego. Si el plan quedó viejo, '
        'reescribilo entero con `set_session_plan` — lo hecho que no cambie de '
        'texto se conserva marcado.',
      );
    } else {
      buffer.writeln(
        'Al cerrar tu turno marcá lo que efectivamente resolviste dejando en '
        'tu respuesta un bloque así, un punto por línea con su texto tal '
        'como está acá arriba:\n'
        '```cumplido\n'
        'puntos:\n'
        'Texto del punto resuelto\n'
        '```\n'
        'Solo esos: marcar de más deja al usuario ciego. Si el plan quedó '
        'viejo, reescribilo entero con un bloque ```plan — lo hecho que no '
        'cambie de texto se conserva marcado.',
      );
    }
    buffer.writeln(
      'El plan es el contrato de la sesión: terminados los pasos, si queda un '
      'punto sin cumplir la sesión NO se da por terminada y pasa a '
      'verificación. Si algo de tu paso queda afuera, decilo en el momento.',
    );
    return buffer.toString().trim();
  }

  String _consultAnswerPrompt(AgentProfile target, String answer) {
    return '@${target.name} respondió tu consulta:\n\n$answer\n\n'
        'Seguí con tu paso usando esa respuesta.';
  }

  /// Composes what this member knows for the whole turn: the global skills
  /// every agent carries, who it is, the project's shared rules and
  /// documents, and who else it can consult.
  ///
  /// El orden es contrato: skills globales → prompt del perfil → skills →
  /// reglas → saber → IDENTIDAD (siempre) → COMPAÑEROS (si hay) → MODO DE
  /// TRABAJO → PLAN → ENTREGA (si hay git y no es consulta) → REGLA DEL
  /// CANAL. Cada regla vive en UNA sección; las demás, si la necesitan,
  /// apuntan a ella.
  String _turnSystemPrompt(
    Project project,
    AgentProfile member, {
    Session? session,
    required bool isConsult,
    required bool hasPlanTools,
    required bool usesGit,
  }) {
    final buffer = StringBuffer();

    final skills = SkillsService.instance.notifier.data.skills;
    for (final skill in skills) {
      if (!skill.isGlobal || skill.content.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(skill.content);
    }

    if (member.systemPrompt.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(member.systemPrompt);
    }

    for (final name in member.skills) {
      final skill = skills.where((s) => s.name == name).firstOrNull;
      if (skill == null || skill.content.isEmpty) {
        Log.w('Skill "$name" referenced by ${member.name} not found or empty');
        continue;
      }
      // Globals already went in above — never inject the same skill twice.
      if (skill.isGlobal) continue;
      buffer.writeln();
      buffer.writeln(skill.content);
    }

    final rules = RulesService.instance.notifier.data.rules;
    final ruleNames = {...member.rules, ...project.ruleNames};
    for (final name in ruleNames) {
      final rule = rules.where((r) => r.name == name).firstOrNull;
      if (rule == null || rule.content.isEmpty) {
        Log.w(
          'Rule "$name" referenced by project "${project.name}" not found or empty',
        );
        continue;
      }
      buffer.writeln();
      buffer.writeln(rule.content);
    }

    final saber = KnowledgeService.instance.notifier.briefFor(
      <String>{
        ...project.knowledgeBaseNames,
        ...member.knowledgeBaseNames,
      }.toList(),
    );
    if (saber.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(saber);
    }

    final companions = membersOf(
      project,
      session: session,
    ).where((m) => m.id != member.id).toList();

    // IDENTIDAD — siempre, haya compañeros o no. Cuando estaba adentro del
    // `if` de compañeros, un proyecto de un solo miembro perdía entero el
    // "SOS @handle" y el nombre del proyecto.
    buffer.writeln();
    buffer.writeln(
      'SOS @${member.name} (${member.role}), trabajando en el proyecto '
      '"${project.name}"'
      '${project.purpose.isEmpty ? '' : ' — ${project.purpose}'}. '
      'Los mensajes del hilo vienen firmados con el handle de quien los '
      'escribió: si no dice @${member.name}, no lo escribiste vos. No '
      'discutas identidades — leé la firma.',
    );

    if (!project.maintained) {
      buffer.writeln();
      buffer.writeln(
        'ESTE PROYECTO NO ES TUYO PARA DECIDIR. No lo mantiene quien te está '
        'usando, así que es de SOLO LECTURA: leelo, entendelo y contestá, '
        'pero no lo cambies. Las tools que escriben no te fueron entregadas '
        'en este turno; si hace falta un cambio, decilo con precisión —qué '
        'archivo, qué cambio y por qué— para que lo pida quien sí lo '
        'mantiene, en vez de intentarlo vos.',
      );
    }

    if (companions.isNotEmpty) {
      buffer.writeln('Tus compañeros en el canal son:');
      for (final companion in companions) {
        buffer.writeln('- @${companion.name} (${companion.role})');
      }
      buffer.writeln(
        'El rol de cada uno es su ÁREA DE AUTORIDAD. Si lo que se pregunta '
        'cae en el área de un compañero, tu trabajo es pasársela mencionando '
        'su @handle — aunque creas que podrías contestarla vos. Su respuesta '
        'es la autorizada; la tuya sería una opinión con forma de dato. No te '
        'saltes ese conducto para contestar de todo vos mismo.',
      );
      buffer.writeln(
        'Podés adelantar contexto o tu lectura del problema, pero la '
        'afirmación de fondo sobre el área de otro la da él, no vos.',
      );
      buffer.writeln(
        'Al mismo tiempo, mencionar DISPARA UN TURNO REAL suyo, con su costo '
        'y su demora: nunca menciones para saludar, agradecer, confirmar que '
        'estás de acuerdo, cerrar un tema ni decir que quedás a disposición. '
        'Para eso escribí el nombre sin la arroba. La regla corta es: por '
        'cortesía nunca, por especialidad siempre.',
      );
      buffer.writeln(
        'Cuando consultes, escribí la pregunta puntual en su propio párrafo, '
        'junto a la mención: al consultado le llega SOLO el párrafo donde lo '
        'nombrás (y el anterior), no todo tu turno. Lo que no esté ahí, no '
        'lo ve.',
      );
      buffer.writeln(
        'Tampoco menciones a quien le toca el paso siguiente para pasarle el '
        'trabajo: el workflow le da la palabra solo cuando vos terminás. Si '
        'lo mencionás, lo que hace corre COMO CONSULTA TUYA, adentro de tu '
        'paso. Y el desempate, cuando el especialista es además el del paso '
        'siguiente, es una sola pregunta: ¿tu paso puede cerrarse sin su '
        'respuesta? Si sí, no lo menciones — decí qué dejás listo y cerrá '
        'el turno. Si no, consultalo con solo la pregunta que te falta.',
      );
      buffer.writeln(
        'Esa lista de compañeros es completa. Mencionar un handle que no '
        'está en ella no dispara nada: no le llega a nadie y no vas a '
        'recibir respuesta, así que no esperes una ni la reclames. Si te '
        'falta un especialista que el proyecto no tiene, declaralo con el '
        'bloque `agente` de la REGLA DEL CANAL en vez de nombrarlo como si '
        'ya estuviera.',
      );
    }

    buffer.writeln();
    buffer.writeln(_askVsWorkPrompt);

    final plan = _planSection(
      session,
      isConsult: isConsult,
      hasPlanTools: hasPlanTools,
    );
    if (plan.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(plan);
    }

    // La entrega es del que trabaja, no del que responde una consulta; y
    // solo tiene sentido donde hay git.
    if (!isConsult && usesGit) {
      buffer.writeln();
      buffer.writeln(_deliveryPrompt);
    }

    buffer.writeln();
    buffer.writeln(_noBackgroundWorkPrompt);

    final combined = buffer.toString().trim();
    return combined;
  }

  // ── helpers de estado ───────────────────────────────────────────────

  Project? _projectById(String id) {
    for (final project in data.projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  /// Dónde corre un proyecto. Para quien tiene el id y no el proyecto —la
  /// burbuja de un mensaje, que necesita resolver una ruta relativa.
  String? workingDirectoryOf(String projectId) =>
      _projectById(projectId)?.workingDirectory;

  Workflow? activeWorkflowOf(Project project) {
    final id = project.activeWorkflowId;
    if (id == null) return null;
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    return workflows.where((workflow) => workflow.id == id).firstOrNull;
  }

  /// The roster a turn sees: the project's members plus [session]'s own
  /// extras. Extras are per-session by design — the project is untouched.
  List<AgentProfile> membersOf(Project project, {Session? session}) {
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    final ids = <String>{...project.profileIds, ...?session?.extraProfileIds};
    return ids
        .map((id) => profiles.where((p) => p.id == id).firstOrNull)
        .whereType<AgentProfile>()
        .toList();
  }

  /// Adds a registered profile to ONE session's roster. No-op if it's already
  /// a member (of the project or the session).
  void addAgentToSession(String projectId, String sessionId, String profileId) {
    final project = _projectById(projectId);
    if (project == null) return;
    if (project.profileIds.contains(profileId)) return;

    _updateSession(projectId, sessionId, (session) {
      if (session.extraProfileIds.contains(profileId)) return session;
      return session.copyWith(
        extraProfileIds: [...session.extraProfileIds, profileId],
      );
    });
    unawaited(_persist());
  }

  /// Removes a TASK-scoped extra. Project members can't be removed from
  /// here — that's the project form's job.
  void removeAgentFromSession(
    String projectId,
    String sessionId,
    String profileId,
  ) {
    _updateSession(projectId, sessionId, (session) {
      return session.copyWith(
        extraProfileIds: session.extraProfileIds
            .where((id) => id != profileId)
            .toList(),
      );
    });
    unawaited(_persist());
  }

  int stepCountFor(Project project) {
    return activeWorkflowOf(project)?.steps.length ?? 0;
  }

  AgentProfile? _memberForRole(
    Project project,
    String role, {
    Session? session,
  }) {
    return memberForRole(membersOf(project, session: session), role);
  }

  String _titleFor(String request) {
    final firstLine = request.split('\n').first.trim();
    if (firstLine.length <= 48) return firstLine;
    return '${firstLine.substring(0, 45)}…';
  }

  Session? _sessionById(Project project, String sessionId) {
    for (final session in project.sessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  void _finishSession(
    String projectId,
    String sessionId,
    SessionStatus status,
  ) {
    _runningSessions.remove(sessionId);
    _purgeConsultLedgerIfIdle();
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        status: status,
        isRunning: false,
        clearLiveTurn: true,
      ),
    );
  }

  void _appendMessage(String projectId, String sessionId, ChatMessage message) {
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(messages: [...session.messages, message]),
    );
  }

  void _annotateLastMessage(
    String projectId,
    String sessionId, {
    required double costUsd,
    required int durationMs,
  }) {
    _updateSession(projectId, sessionId, (session) {
      final messages = [...session.messages];
      for (var i = messages.length - 1; i >= 0; i--) {
        if (messages[i].role != ChatRole.assistant) continue;
        final message = messages[i];
        messages[i] = ChatMessage(
          role: message.role,
          text: message.text,
          timestamp: message.timestamp,
          costUsd: costUsd,
          durationMs: durationMs,
          reasoning: message.reasoning,
          fileEdits: message.fileEdits,
          authorProfileId: message.authorProfileId,
          stepIndex: message.stepIndex,
          consultOfProfileId: message.consultOfProfileId,
        );
        break;
      }
      return session.copyWith(messages: messages);
    });
  }

  /// Narrows [_updateSession] to the turn in flight, so a chunk that arrives
  /// after the turn ended is dropped instead of resurrecting a dead strip.
  void _updateLiveTurn(
    String projectId,
    String sessionId,
    SessionLiveTurn Function(SessionLiveTurn turn) update,
  ) {
    _updateSession(projectId, sessionId, (session) {
      final turn = session.liveTurn;
      if (turn == null) return session;
      return session.copyWith(liveTurn: update(turn));
    });
  }

  void _updateSession(
    String projectId,
    String sessionId,
    Session Function(Session session) transform,
  ) {
    _updateProject(projectId, (project) {
      final sessions = project.sessions
          .map(
            (session) => session.id == sessionId ? transform(session) : session,
          )
          .toList();
      return project.copyWith(sessions: sessions);
    });
  }

  void _updateProject(
    String projectId,
    Project Function(Project project) transform,
  ) {
    final projects = data.projects
        .map(
          (project) => project.id == projectId ? transform(project) : project,
        )
        .toList();
    updateState(data.copyWith(projects: projects));
  }

  /// Renombra [from] a [to] en todos los proyectos. Espejo de
  /// `AgentProfilesViewModel.renameHook`.
  void renameHook(String from, String to) {
    if (!data.projects.any((project) => project.hookNames.contains(from))) {
      return;
    }
    final projects = data.projects
        .map(
          (project) => project.hookNames.contains(from)
              ? project.copyWith(
                  hookNames: [
                    for (final name in project.hookNames)
                      name == from ? to : name,
                  ],
                )
              : project,
        )
        .toList();
    updateState(data.copyWith(projects: projects));
    unawaited(_persist());
  }

  /// Saca [hookName] de todos los proyectos que lo tenían. Espejo de
  /// `AgentProfilesViewModel.detachHook`, por la misma razón: una
  /// asignación que apunta a un guardarraíl borrado miente sobre qué está
  /// protegido.
  /// Los hooks que corren en este turno: globales + los del perfil del
  /// miembro + los del proyecto.
  /// [member] ya viene con el motor del proyecto aplicado
  /// (`project.tuned`), así que de ahí sale el proveedor. Los hooks
  /// asignados son los mismos del perfil: afinar el motor no cambia qué
  /// guardarraíles lleva.
  Future<TurnHooks> _resolveTurnHooks(
    Project project,
    AgentProfile member,
  ) async {
    await HooksService.instance.notifier.ready;
    final catalog = HooksService.instance.notifier.data.hooks;
    if (catalog.isEmpty) return TurnHooks.none;

    final tools = ToolsService.instance.notifier.data.tools;
    return prepareTurnHooks(
      catalog: catalog,
      tools: tools,
      secretValues: SecretsService.instance.notifier.valuesFor(
        hookSecretNames(catalog, tools),
      ),
      provider: member.provider == AgentProvider.codex
          ? HookProvider.codex
          : HookProvider.claude,
      profile: member,
      project: project,
    );
  }

  int detachHook(String hookName) {
    final affected = data.projects
        .where((project) => project.hookNames.contains(hookName))
        .length;
    if (affected == 0) return 0;

    final projects = data.projects
        .map(
          (project) => project.hookNames.contains(hookName)
              ? project.copyWith(
                  hookNames: project.hookNames
                      .where((name) => name != hookName)
                      .toList(),
                )
              : project,
        )
        .toList();
    updateState(data.copyWith(projects: projects));
    unawaited(_persist());
    return affected;
  }

  Future<void> _persist() => _repository.save(data.projects);
}

mixin ProjectsService {
  static final ReactiveNotifier<ProjectsViewModel> instance =
      ReactiveNotifier<ProjectsViewModel>(() => ProjectsViewModel());
}
