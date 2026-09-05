import 'dart:async';
import 'dart:convert';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/integrations/git_worktree/git_worktree.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/integrations/workspace_roots/workspace_roots.dart';
import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';
import 'package:keel_ui/src/integrations/machine/machine.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_ui/src/integrations/session_plan_mcp/session_plan_mcp_server.dart';
import 'package:keel_ui/src/integrations/decisions_mcp/decisions_mcp_server.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/integrations/project_radar/project_radar.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/roadmap/viewmodel/task_claims_viewmodel.dart';
import 'package:keel_ui/src/integrations/requirements_mcp/requirements_mcp.dart';
import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/plan_decision.dart';
import 'package:keel_ui/src/modules/agents/service/remote_conversation_history.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/integrations/boards_mcp/boards_mcp.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/member_tuning.dart';
import 'package:keel_ui/src/modules/projects/model/roadmap_format_skill.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/model/session_queued_message.dart';
import 'package:keel_ui/src/modules/projects/model/session_usage.dart';
import 'package:keel_ui/src/modules/projects/model/token_usage.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_preflight.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/repository/projects_repository.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/projects/service/resolution_engine.dart';
import 'package:keel_ui/src/modules/projects/service/node_context.dart';
import 'package:keel_ui/src/modules/projects/service/subagent_budget.dart';
import 'package:keel_ui/src/modules/projects/service/turn_watchdog.dart';
import 'package:keel_ui/src/modules/projects/service/turn_prompt.dart';
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

const _coverageBlockKeys = {'area', 'estado', 'motivo'};

/// Cómo terminó un turno de CLI: si produjo una respuesta usable y cuál fue.
///
/// Antes el turno no devolvía nada y las decisiones que dependían de él se
/// tomaban mirando el hilo — la "respuesta" de una consulta era el último
/// mensaje de la sesión, fuera de quien fuera, y un paso fallido dejaba al
/// ciclo marchar igual por los pasos restantes.
typedef TurnOutcome = ({bool ok, String answer, TurnOutcomeReport? report});

class _AdaptivePreflightResult {
  const _AdaptivePreflightResult({
    required this.owner,
    required this.preflight,
    this.nodeOwners = const {},
  });

  final AgentProfile? owner;
  final Map<String, AgentProfile> nodeOwners;
  final ResolutionPreflight preflight;
  String? get error => preflight.ready ? null : preflight.errorSummary;
}

/// Cada cuánto se relee el roadmap para la fila de Estado del sidebar.
const _kBadgeTtl = Duration(seconds: 15);

/// El título con el que nace una sesión. Vale como marca de "todavía no
/// tiene nombre propio": mientras siga siendo este, el primer pedido la
/// renombra sola.
const kDefaultSessionTitle = 'Sesión nueva';

class ProjectsViewModel extends ViewModel<ProjectsState> {
  ProjectsViewModel() : super(const ProjectsState());

  ProjectsRepository get _repository => ProjectsRepository();

  /// Keyed by **session**, not by project: a project can have several sessions in
  /// flight at once, each owning its own runner. Within one session the turns
  /// still run strictly in sequence, so the agents of a single session never
  /// write files on top of each other.
  final Map<String, TaskRun> _runningSessions = {};

  /// The outer session futures, including the gaps between CLI turns. A
  /// missing [TaskRun] does not mean the workflow has handed control back,
  /// so "send now" uses this set before deciding whether it is safe to start
  /// the queued follow-up.
  final Set<String> _activeSessionRuns = {};

  /// Los vigilantes de los turnos vivos, por sesión. Una decisión pendiente
  /// los pausa (la espera humana no es inactividad del agente).
  final Map<String, Set<TurnWatchdog>> _turnWatchdogs = {};

  /// Los turnos VIVOS suspendidos esperando una decisión, por id de
  /// decisión. Completar uno destraba el hook o la tool que esperaba.
  final Map<String, Completer<SessionDecision>> _gateCompleters = {};

  /// Reference resolution may touch the filesystem before a turn owns a CLI.
  /// This closes that short gap so two fast sends cannot start two turns for
  /// the same session while the first one is still materializing its links.
  final Set<String> _preparingSessionTurns = {};

  /// Lo último que se leyó del roadmap de cada proyecto, para el sidebar.
  final Map<String, ({DateTime at, int percent, bool ok})> _radarBadges = {};
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
  final SubagentBudget _subagentBudget = SubagentBudget();

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
    if (_runningSessions.isEmpty) {
      _consultedPairs.clear();
      _subagentBudget.clear();
    }
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
      await WorkflowsService.instance.notifier.ready;
      final revived = _revived(projects);
      final existingWorkflowIds = WorkflowsService
          .instance
          .notifier
          .data
          .workflows
          .map((workflow) => workflow.id)
          .toSet();
      final hadBrokenReferences = revived.any(
        (project) => project.referencedWorkflowIds.any(
          (workflowId) => !existingWorkflowIds.contains(workflowId),
        ),
      );
      final repaired = repairWorkflowReferences(revived, existingWorkflowIds);
      updateState(data.copyWith(projects: repaired));
      if (hadBrokenReferences) await _repository.save(repaired);
    } catch (error) {
      Log.e('Failed to load persisted projects', error: error);
    }
  }

  /// Pure half of the startup repair, exposed so the persistence migration is
  /// regression-testable without opening the native database.
  static List<Project> repairWorkflowReferences(
    List<Project> projects,
    Set<String> existingWorkflowIds,
  ) => [
    for (final project in projects)
      project.retainingWorkflows(existingWorkflowIds),
  ];

  /// No CLI process survives closing the app, so a session that comes back from
  /// disk saying it is running is lying — it was interrupted mid-turn. Left
  /// alone the flag never clears: the composer stays disabled, the progress
  /// bar spins forever, and `sendToChannel` returns early on every message.
  /// The channel looks hung because, as far as the state is concerned, it is.
  /// Lo que hay que arreglar de lo guardado antes de mostrarlo.
  ///
  /// Dos cosas: una sesión no puede quedar «corriendo» después de cerrar la
  /// app —el proceso que la corría murió con ella— y las sesiones de cuando
  /// el workflow era del PROYECTO no traen con cuál corrieron. Se les
  /// escribe uno: el de formato a las que llevaban la vieja marca, el de por
  /// defecto al resto. Es una migración de una sola vez, no un `?? default`
  /// colgando para siempre: en cuanto se guarda queda el id de verdad.
  List<Project> _revived(List<Project> projects) {
    final formatId = roadmapFormatWorkflowId();
    return [
      for (final project in projects)
        project.copyWith(
          sessions: [
            for (final session in project.sessions)
              revivedSession(session, project, formatId),
          ],
        ),
    ];
  }

  /// Cómo queda UNA sesión guardada al revivirla. Pura: es la mitad de
  /// [_revived] que se puede mirar sin base de datos.
  static Session revivedSession(
    Session session,
    Project project,
    String formatWorkflowId,
  ) {
    final workflowId = switch (session.workflowId) {
      kSessionFormatMigrationMark => formatWorkflowId,
      '' => project.activeWorkflowId ?? '',
      final id => id,
    };
    final hasDeliveryWaitingForDeadRun = session.queuedMessages.any(
      (message) => message.delivery != SessionQueuedDelivery.standby,
    );
    final hasBlockingDecision = session.decisions.any(
      (decision) => decision.isPending && decision.blocking,
    );
    if (!session.isRunning &&
        workflowId == session.workflowId &&
        !hasDeliveryWaitingForDeadRun &&
        !hasBlockingDecision) {
      return session;
    }
    return session.copyWith(
      isRunning: false,
      workflowId: workflowId,
      queuedMessages: [
        for (final message in session.queuedMessages)
          message.copyWith(delivery: SessionQueuedDelivery.standby),
      ],
      // Una decisión bloqueante esperaba a un proceso que murió con la app:
      // se cancela para que la tarjeta no prometa destrabar nada.
      decisions: [
        for (final decision in session.decisions)
          decision.isPending && decision.blocking
              ? decision.copyWith(
                  status: SessionDecisionStatus.cancelled,
                  resolvedAt: DateTime.now(),
                )
              : decision,
      ],
    );
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
    unawaited(_rememberRoot(project.workingDirectory));
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
    unawaited(_rememberRoot(workingDirectory.trim()));
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
    // Los requerimientos que lo nombran NO se borran: son historia
    // compartida y el otro lado sigue teniendo derecho a verla. Lo que sí
    // pasa es que dejan de poder tomarse.
    RequirementsService.instance.notifier.markProjectDeleted(id);

    // Los tableros SÍ se van con él, al revés que los requerimientos: un
    // tablero prueba la API de ESTE repo y sin su directorio de trabajo no
    // prueba nada. Dejarlo huérfano sería dejar un botón que dispara contra
    // algo que ya no seguís.
    BoardsService.instance.notifier.deleteBoardsOfProject(id);

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

  /// Overrides the concrete agent for one adaptive capability in one project.
  /// A running or completed node keeps its persisted owner for traceability.
  ///
  /// Un [profileId] vacío es un BORRADO, y el bloqueo no lo alcanza: sacar un
  /// override no le cambia el dueño a un caso en curso —el nodo conserva el
  /// suyo, que es de lo que hablaba la traza—, solo deja de imponer uno para
  /// el próximo. Bloquearlo también dejaba sin forma de limpiar una fila que
  /// ya no gobierna a nadie.
  bool setWorkflowNodeAssignment(
    String projectId,
    String workflowId,
    String nodeId,
    String? profileId,
  ) {
    final project = _projectById(projectId);
    if (project == null) return false;
    final isRemoval = profileId == null || profileId.isEmpty;
    final activeSession = project.activeSession;
    final activeNode = activeSession?.workflowId == workflowId
        ? activeSession?.resolutionCase?.nodes
              .where((node) => node.id == nodeId)
              .firstOrNull
        : null;
    if (!isRemoval &&
        activeNode != null &&
        (activeNode.status == WorkNodeStatus.running ||
            activeNode.status == WorkNodeStatus.done)) {
      return false;
    }
    _updateProject(projectId, (current) {
      final assignments = {
        for (final entry in current.workflowNodeAssignments.entries)
          entry.key: Map<String, String>.from(entry.value),
      };
      final nodes = assignments.putIfAbsent(workflowId, () => {});
      if (profileId == null || profileId.isEmpty) {
        nodes.remove(nodeId);
      } else {
        nodes[nodeId] = profileId;
      }
      if (nodes.isEmpty) assignments.remove(workflowId);
      final sessions = [
        for (final session in current.sessions)
          if (session.id != current.activeSessionId ||
              session.workflowId != workflowId ||
              session.resolutionCase == null)
            session
          else
            session.copyWith(
              resolutionCase: session.resolutionCase!.copyWith(
                nodes: [
                  for (final node in session.resolutionCase!.nodes)
                    if (node.id == nodeId &&
                        node.status != WorkNodeStatus.running &&
                        node.status != WorkNodeStatus.done)
                      node.copyWith(ownerProfileId: profileId ?? '')
                    else
                      node,
                ],
              ),
            ),
      ];
      return current.copyWith(
        workflowNodeAssignments: assignments,
        sessions: sessions,
      );
    });
    unawaited(_persist());
    return true;
  }

  /// Instantiates an optional workflow capability only when it is needed.
  /// The owner is resolved with the same project override/default-role rules
  /// as preflight, so activating it never creates an anonymous session.
  Future<String?> activateWorkflowCapability(
    String projectId,
    String sessionId,
    String capabilityId,
  ) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final workflow = session == null ? null : workflowOf(session);
    final resolution = session?.resolutionCase;
    if (project == null ||
        session == null ||
        workflow == null ||
        resolution == null) {
      return 'No hay un caso adaptativo activo.';
    }
    if (resolution.status == ResolutionCaseStatus.completed) {
      return 'El caso ya está cerrado.';
    }
    final capability = workflow.capabilities
        .where((entry) => entry.id == capabilityId)
        .firstOrNull;
    if (capability == null ||
        capability.activation != WorkflowCapabilityActivation.optional) {
      return 'La capacidad no es opcional o no existe.';
    }
    if (resolution.nodes.any((node) => node.id == capabilityId)) return null;

    final members = membersOf(project, session: session);
    final overrideId = project.assignedProfileId(workflow.id, capability.id);
    final owner = overrideId == null
        ? memberForRole(members, capability.role) ??
              (capability.role == '*'
                  ? memberForRole(members, resolution.ownerRole)
                  : null)
        : members.where((member) => member.id == overrideId).firstOrNull;
    if (owner == null) {
      return 'No hay agente para el rol ${capability.role}.';
    }
    if (capability.requiresIndependentOwner) {
      final dependencyOwnerIds = resolution.nodes
          .where((node) => capability.dependencyIds.contains(node.id))
          .map((node) => node.ownerProfileId)
          .where((id) => id.isNotEmpty)
          .toSet();
      if (dependencyOwnerIds.contains(owner.id)) {
        return 'La capacidad ${capability.title} requiere un agente '
            'independiente de quien produjo sus dependencias.';
      }
    }
    await SecretsService.instance.notifier.ready;
    final secretName = project.tuned(owner).provider.secretName;
    if (secretName != null &&
        (SecretsService.instance.notifier.pendingOf([secretName]).isNotEmpty ||
            SecretsService.instance.notifier.missingOf([
              secretName,
            ]).isNotEmpty)) {
      return 'Falta configurar $secretName.';
    }

    _storeResolution(
      projectId,
      sessionId,
      ResolutionEngine.activateCapability(
        resolution,
        capability: capability,
        ownerProfileId: owner.id,
      ),
    );
    await _persist();
    return null;
  }

  /// Continues a workflow that intentionally stopped at a manual publication
  /// gate. This is separate from tool permissions: it never widens a sandbox
  /// or changes a global setting.
  Future<String?> approveWorkflowCapability(
    String projectId,
    String sessionId,
    String capabilityId,
  ) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final workflow = session == null ? null : workflowOf(session);
    final resolution = session?.resolutionCase;
    if (project == null ||
        session == null ||
        workflow == null ||
        resolution == null) {
      return 'No hay un workflow esperando aprobación.';
    }
    final capability = _capabilityFor(workflow, capabilityId);
    final node = resolution.nodes
        .where((entry) => entry.id == capabilityId)
        .firstOrNull;
    if (capability.executor != WorkflowExecutor.manualApproval ||
        node?.status != WorkNodeStatus.paused) {
      return 'Este paso no está esperando aprobación manual.';
    }
    final approved = _replaceNode(
      resolution.copyWith(status: ResolutionCaseStatus.active),
      capabilityId,
      WorkNodeStatus.done,
    );
    _storeResolution(projectId, sessionId, approved);
    await _persist();
    await _runWorkflow(projectId, sessionId, session.request);
    return null;
  }

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
        final marca = item.discarded ? '–' : (item.done ? '✓' : '○');
        buffer.write('\n$marca  ${item.text}');
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
            // Lo que el usuario descartó no lo devuelve el agente. Decidir
            // que algo no se hace es suyo, y marcarlo cumplido por atrás
            // borraría esa decisión sin que nadie se entere. Cuenta como
            // encontrado igual: no es un error del agente, es que ya no
            // aplica.
            if (item.discarded) return item;
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
  ///
  /// Sobre uno DESCARTADO no marca nada: lo devuelve a la mesa. Es el único
  /// camino de vuelta, y ponerlo acá evita que tocar un punto tachado lo
  /// selle como cumplido, que es exactamente lo contrario de lo que se pidió.
  void togglePlanItem(String projectId, String sessionId, String itemId) {
    _updateSession(projectId, sessionId, (session) {
      return session.copyWith(
        plan: [
          for (final item in session.plan)
            if (item.id != itemId)
              item
            else if (item.discarded)
              item.copyWith(discarded: false)
            else
              item.copyWith(done: !item.done, clearDoneBy: item.done),
        ],
      );
    });
    unawaited(_persist());
  }

  /// Saca un punto de la mesa: no se va a hacer.
  ///
  /// No es marcarlo cumplido —eso le mentiría al hilo y al chequeo de
  /// cierre— ni borrarlo: queda escrito que se decidió no hacerlo, y con eso
  /// la sesión puede cerrar sin que el punto la trabe para siempre.
  ///
  /// Queda dicho en el hilo porque es una decisión del usuario que cambia lo
  /// que el equipo tiene que hacer, y el hilo es donde el equipo mira.
  void discardPlanItem(String projectId, String sessionId, String itemId) {
    final item = planOf(
      projectId,
      sessionId,
    ).where((entry) => entry.id == itemId).firstOrNull;
    if (item == null || item.discarded) return;

    _updateSession(projectId, sessionId, (session) {
      return session.copyWith(
        plan: [
          for (final entry in session.plan)
            if (entry.id == itemId)
              entry.copyWith(discarded: true, done: false, clearDoneBy: true)
            else
              entry,
        ],
      );
    });
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.system,
        text:
            'El usuario descartó el punto "${item.text}": no se hace. No '
            'cuenta como cumplido y la sesión ya no lo espera.',
        timestamp: DateTime.now(),
      ),
    );
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
  /// Abre en el proyecto DESTINO la sesión que evalúa un requerimiento.
  ///
  /// El pedido inicial es el requerimiento renderizado y nada más: el hilo
  /// del que pidió no viaja, y de este lado no hay forma de alcanzarlo.
  ///
  /// Devuelve el id de la sesión, para que quien apretó el botón navegue
  /// hacia ella. Acá no se navega: crear no es ir.
  String? startRequirementSession({
    required String projectId,
    required String sessionTitle,
    required String request,
    String? workflowId,
  }) {
    final project = _projectById(projectId);
    if (project == null) return null;

    final session = Session(
      id: generateUuidV4(),
      title: sessionTitle,
      createdAt: DateTime.now(),
      // Evaluar un requerimiento no es lo mismo que resolver un ticket, y el
      // proyecto destino puede tener un workflow para eso. Quien lo toma
      // elige; sin elección, el de siempre.
      workflowId: workflowId ?? project.activeWorkflowId ?? '',
    );
    _updateProject(
      projectId,
      (project) => project.copyWith(
        sessions: [...project.sessions, session],
        activeSessionId: session.id,
      ),
    );
    unawaited(_persist());
    unawaited(sendToChannel(projectId, request));
    return session.id;
  }

  /// Abre la sesión que le da formato al roadmap del proyecto.
  ///
  /// Es la única salida que ofrece la pantalla de Estado cuando la carpeta no
  /// cierra, y arranca sola: el pedido ya trae el diagnóstico concreto —qué
  /// falta, archivo por archivo— en vez de mandar al agente a descubrirlo.
  ///
  /// La especificación del formato no viaja acá: vive en el skill
  /// [kRoadmapFormatSkillName], que se siembra en cada arranque y llega por
  /// el system prompt como cualquier otro.
  ///
  /// Devuelve el id de la sesión que hay que mirar, para que quien apretó el
  /// botón navegue hacia ella. Acá no se navega: crear no es ir, y esa regla
  /// vale también para lo que arranca solo.
  ///
  /// **Una sola a la vez.** Si ya hay una sin terminar, devuelve esa y no
  /// abre otra: dos sesiones arreglando la MISMA carpeta se pisan los
  /// archivos, y la segunda arrancaría con un diagnóstico que la primera está
  /// cambiando abajo suyo.
  String? startRoadmapFormatSession(String projectId) {
    final project = _projectById(projectId);
    if (project == null) return null;

    final pending = openFormatSessionOf(project);
    if (pending != null) return pending.id;

    final check = checkRoadmapFormat(project.workingDirectory);
    final session = Session(
      id: generateUuidV4(),
      title: kRoadmapFormatSessionTitle,
      createdAt: DateTime.now(),
      // Su workflow específico usa el caso mínimo de formato y su skill.
      // Así no abre trabajo de implementación o entrega para unos markdown.
      workflowId: roadmapFormatWorkflowId(),
    );
    _updateProject(
      projectId,
      (project) => project.copyWith(
        sessions: [...project.sessions, session],
        activeSessionId: session.id,
      ),
    );
    unawaited(_persist());
    // Antes de que el agente escriba un solo archivo: la carpeta que está por
    // crear es la libreta de trabajo de Keel, y no tiene por qué aparecer en
    // el `git status` del usuario ni terminar comiteada con el código.
    unawaited(ensureRoadmapIgnored(project.workingDirectory));
    unawaited(sendToChannel(projectId, _roadmapFormatRequest(project, check)));
    return session.id;
  }

  /// La sesión de formato de [project] que todavía no cerró, si hay alguna.
  ///
  /// `failed` cuenta como abierta y no es un descuido: cuando el chequeo no
  /// pasa, la sesión queda en `failed` a propósito —el veredicto es «arreglá
  /// eso y volvé a cerrar»— y sigue siendo la sesión donde continuar.
  static Session? openFormatSessionOf(Project project) {
    for (final session in project.sessions) {
      if (session.status == SessionStatus.finished) continue;
      if (_workflowById(session.workflowId)?.buildsRoadmap ?? false) {
        return session;
      }
    }
    return null;
  }

  String _roadmapFormatRequest(Project project, RoadmapFormatCheck check) {
    final buffer = StringBuffer()
      ..writeln(
        'Dejá la carpeta de tareas de este proyecto con el formato de keel-ui '
        '(el skill "$kRoadmapFormatSkillName" lo describe entero).',
      );
    if (check.findings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Hoy falla esto, chequeado sobre la carpeta:');
      for (final finding in check.findings) {
        buffer.writeln('- $finding');
      }
    }
    if (check.passed.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Esto ya está bien y no hay que tocarlo:');
      for (final done in check.passed) {
        buffer.writeln('- $done');
      }
    }
    buffer
      ..writeln()
      ..writeln(
        'El objetivo del proyecto es: '
        '${project.purpose.isEmpty ? '(sin propósito escrito — preguntá antes de inventarlo)' : project.purpose}',
      )
      ..writeln()
      ..writeln(
        'Cuando cierres, keel-ui vuelve a correr el chequeo solo. Si algo '
        'sigue mal, la sesión NO se da por terminada y te vuelve la lista.',
      );
    return buffer.toString();
  }

  /// Cierra la sesión abierta del proyecto, sin borrarla.
  ///
  /// Qué se está mirando NO se decide acá: eso es un lente y vive en
  /// `WorkspaceViewModel`. Este método solo hace lo suyo —dejar el proyecto
  /// sin sesión activa—, que es la mitad de lo que hace falta para ir a
  /// Estado y por eso siempre se llama desde ahí.
  void showProjectState(String projectId) {
    selectProject(projectId);
    _updateProject(
      projectId,
      (project) => project.copyWith(clearActiveSession: true),
    );
    unawaited(_persist());
  }

  /// Lo que muestra la fila de Estado en el sidebar, con una caché corta.
  ///
  /// Se pide para UN proyecto —el seleccionado, que es el único que dibuja
  /// esa fila— y se relee como mucho una vez cada [_kBadgeTtl]. Recorrer un
  /// directorio es barato; hacerlo en cada `build` de una lista, no.
  ({int percent, bool ok}) radarBadgeFor(Project project) {
    final cached = _radarBadges[project.id];
    final now = DateTime.now();
    if (cached != null && now.difference(cached.at) < _kBadgeTtl) {
      return (percent: cached.percent, ok: cached.ok);
    }

    final check = checkRoadmapFormat(project.workingDirectory);
    final radar = buildProjectRadar(
      project: project,
      roadmap: check.ok ? readRoadmap(project.workingDirectory) : const [],
      claims: TaskClaimsService.instance.notifier.activeClaimsFor(
        project.workingDirectory,
      ),
      totalSteps: nodeCountFor(project),
      now: now,
      hasRoadmap: check.ok,
    );
    final badge = (at: now, percent: radar.completionPercent, ok: check.ok);
    _radarBadges[project.id] = badge;
    return (percent: badge.percent, ok: badge.ok);
  }

  /// Consulta a OTRO proyecto y devuelve solo su respuesta en texto.
  ///
  /// Corre un agente aparte, en el directorio del otro proyecto, en modo
  /// lectura. **Lo que cruza es la respuesta, no el acceso**: quien pregunta
  /// nunca recibe la carpeta del otro, ni sus reglas, ni su hilo. Es la
  /// diferencia entre preguntar y mudarse.
  ///
  /// No abre un requerimiento: una consulta es una pregunta, no un pedido de
  /// trabajo.
  Future<String> askProject({
    required String toProjectName,
    required String question,
  }) async {
    final target = data.projects
        .where(
          (project) =>
              project.name.toLowerCase() == toProjectName.trim().toLowerCase(),
        )
        .firstOrNull;
    if (target == null) {
      return 'No hay ningún proyecto registrado con el nombre '
          '"$toProjectName". Registralo y volvé a preguntar.';
    }
    if (target.workingDirectory.trim().isEmpty) {
      return 'El proyecto "${target.name}" no tiene carpeta de trabajo '
          'elegida, así que no hay nada que leer.';
    }

    final member = membersOf(target).firstOrNull;
    final engine = member == null ? null : target.tuned(member);
    final provider = engine?.provider ?? AgentProvider.claude;
    final model = engine?.model ?? kDefaultClaudeModelAlias;
    final effort = engine?.effort ?? kDefaultEffortAlias;

    final run = await TaskRunner.run(
      TaskRunSpec(
        prompt: question,
        workingDirectory: target.workingDirectory,
        model: model,
        fullFileSystemAccess: false,
        effort: effort,
        // SIN tools que escriban y sin un solo MCP: esto lee y contesta.
        extraAllowedTools: const [],
        additionalSystemPrompt:
            'Te están consultando DESDE OTRO PROYECTO. Estás parado en el '
            'repo de "${target.name}" y sos de solo lectura: leé lo que haga '
            'falta y contestá la pregunta en texto, concreto y corto. No '
            'cambies nada. Si lo que preguntan no está o no se entiende, '
            'decilo en vez de suponer — del otro lado no pueden verificarte.',
        provider: provider.alias,
        providerApiKey: engine == null
            ? null
            : await SecretsService.instance.notifier.resolveValue(
                provider.secretName,
              ),
      ),
    );

    final buffer = StringBuffer();
    var failure = '';
    await for (final event in run.events) {
      if (event is TaskAssistantText) buffer.write(event.text);
      if (event case final TaskTurnCompleted turn) {
        unawaited(
          UsageLedgerService.instance.notifier.record(
            provider: provider.alias,
            model: turn.model.isEmpty ? model : turn.model,
            profileId: member?.id ?? '',
            projectId: target.id,
            sessionId: '',
            workNodeId: '',
            inputTokens: turn.inputTokens,
            outputTokens: turn.outputTokens,
            cacheReadTokens: turn.cacheReadTokens,
            cacheCreationTokens: turn.cacheCreationTokens,
            tokensReported: turn.tokensReported,
            durationMs: turn.durationMs,
            costUsd: turn.costUsd,
            costReported: turn.costReported,
            contextUsedTokens: turn.contextUsedTokens,
            contextWindowTokens: turn.contextWindowTokens,
          ),
        );
        if (turn.isError && failure.isEmpty) {
          failure = provider.turnFailureMessage();
        }
      }
      if (event case TaskFailure(:final message)) {
        failure = message;
      }
    }
    if (failure.isNotEmpty) {
      return 'La consulta a "${target.name}" falló: $failure';
    }
    final answer = buffer.toString().trim();
    return answer.isEmpty
        ? 'El proyecto "${target.name}" no devolvió nada.'
        : answer;
  }

  /// Trae a [member] a contestar dentro del hilo de un requerimiento.
  ///
  /// Es el escalón que faltaba entre «el hilo es un documento» y «tomar y
  /// evaluar». Antes de esto, preguntarle al otro lado si algo aplica exigía
  /// abrirle una sesión de trabajo entera; ahora se lo nombra con `@` y
  /// contesta ahí mismo.
  ///
  /// **Corre sin sesión**, igual que [askProject] y por la misma razón: una
  /// sesión es donde se trabaja, y acá todavía no se decidió trabajar. Sin
  /// sesión no hay hilo de origen que se pueda filtrar, que es justo lo que
  /// la frontera prohíbe.
  ///
  /// **Sin un solo MCP y sin tools que escriban.** No es una promesa del
  /// prompt: sin el servidor de requerimientos enchufado, este turno no
  /// puede tomar, ni dictaminar, ni convertir aunque quiera. Lee su propio
  /// repo con las tools de lectura que todo turno tiene, y contesta.
  ///
  /// Lo único que cruza sigue siendo [renderRequirementForTurn].
  Future<void> answerInRequirementThread({
    required InternalRequirement requirement,
    required AgentProfile member,
    required Project memberProject,
    required bool asTarget,
    required String question,
    bool planMode = false,
  }) async {
    final requirements = RequirementsService.instance.notifier;
    if (memberProject.workingDirectory.trim().isEmpty) {
      requirements.reply(
        requirement.id,
        side: RequirementSide.usuario,
        kind: RequirementEntryKind.correccion,
        text:
            'No pude preguntarle a @${member.name}: el proyecto '
            '"${memberProject.name}" no tiene carpeta de trabajo elegida.',
      );
      return;
    }

    final from = _projectById(requirement.fromProjectId);
    final to = _projectById(requirement.toProjectId);
    final engine = memberProject.tuned(member);

    requirements.markThinking(requirement.id, true);
    try {
      final run = await TaskRunner.run(
        TaskRunSpec(
          prompt: [
            renderRequirementForTurn(
              requirement,
              fromProject: from?.name ?? 'un proyecto que ya no existe',
              toProject: to?.name ?? 'un proyecto que ya no existe',
              purpose: RequirementTurnPurpose.consultar,
            ),
            'TE PREGUNTAN ESTO:\n$question',
          ].join('\n\n'),
          workingDirectory: memberProject.workingDirectory,
          model: engine.model,
          fullFileSystemAccess: false,
          effort: engine.effort,
          extraAllowedTools: const [],
          additionalSystemPrompt: _requirementConsultPrompt(
            member: member,
            project: memberProject,
            asTarget: asTarget,
          ),
          // El turno del hilo ya es de solo lectura; el modo plan acá cambia
          // CÓMO contesta —propone en vez de afirmar— y no qué puede tocar.
          planMode: planMode,
          provider: engine.provider.alias,
          providerApiKey: await SecretsService.instance.notifier.resolveValue(
            engine.provider.secretName,
          ),
        ),
      );

      final buffer = StringBuffer();
      var failure = '';
      await for (final event in run.events) {
        if (event is TaskAssistantText) buffer.write(event.text);
        if (event case final TaskTurnCompleted turn) {
          unawaited(
            UsageLedgerService.instance.notifier.record(
              provider: engine.provider.alias,
              model: turn.model.isEmpty ? engine.model : turn.model,
              profileId: member.id,
              projectId: memberProject.id,
              sessionId: '',
              workNodeId: '',
              inputTokens: turn.inputTokens,
              outputTokens: turn.outputTokens,
              cacheReadTokens: turn.cacheReadTokens,
              cacheCreationTokens: turn.cacheCreationTokens,
              tokensReported: turn.tokensReported,
              durationMs: turn.durationMs,
              costUsd: turn.costUsd,
              costReported: turn.costReported,
              contextUsedTokens: turn.contextUsedTokens,
              contextWindowTokens: turn.contextWindowTokens,
            ),
          );
          if (turn.isError && failure.isEmpty) {
            failure = engine.provider.turnFailureMessage(
              memberName: member.name,
            );
          }
        }
        if (event case TaskFailure(:final message)) failure = message;
      }
      final answer = buffer.toString().trim();

      if (failure.isNotEmpty || answer.isEmpty) {
        requirements.reply(
          requirement.id,
          side: RequirementSide.usuario,
          kind: RequirementEntryKind.correccion,
          text: failure.isEmpty
              ? '@${member.name} no devolvió nada.'
              : 'La consulta a @${member.name} falló: $failure',
        );
        return;
      }

      requirements.reply(
        requirement.id,
        side: asTarget ? RequirementSide.destino : RequirementSide.origen,
        kind: asTarget
            ? RequirementEntryKind.avance
            : RequirementEntryKind.respuesta,
        text: answer,
        handle: member.name,
      );
    } finally {
      requirements.markThinking(requirement.id, false);
    }
  }

  /// Quién sos y qué podés hacer, para una consulta dentro de un hilo.
  ///
  /// Va el `systemPrompt` del perfil y NO su stack de skills y reglas: eso es
  /// la doctrina de cómo trabaja, y acá no se le pide que trabaje sino que
  /// diga si algo aplica. Es la misma decisión que ya tomó [askProject].
  String _requirementConsultPrompt({
    required AgentProfile member,
    required Project project,
    required bool asTarget,
  }) {
    final buffer = StringBuffer();
    if (member.systemPrompt.trim().isNotEmpty) {
      buffer
        ..writeln(member.systemPrompt.trim())
        ..writeln();
    }
    buffer.writeln(
      'SOS @${member.name} (${member.role}), del proyecto "${project.name}", '
      'y te están preguntando algo DENTRO DEL HILO de un requerimiento. '
      '${asTarget ? 'Sos el lado al que se lo piden.' : 'Sos el lado que lo pidió.'} '
      'Estás parado en tu propio repo y sos de SOLO LECTURA en este turno: '
      'leé lo que haga falta —tu código, tu roadmap— y contestá en texto, '
      'concreto y corto. No cambies nada.\n'
      'Esto es una conversación, no el trabajo: no tenés las tools del '
      'requerimiento acá, así que no podés tomarlo, dictaminarlo ni '
      'convertirlo en tarea, y no hace falta que lo anuncies. Cuando haya '
      'acuerdo, eso pasa en otro lado.\n'
      'Lo que contestes lo leen los dos proyectos. Si algo no lo sabés o no '
      'lo podés verificar desde acá, decilo en vez de suponer: del otro lado '
      'no tienen cómo comprobarte.',
    );
    return buffer.toString().trim();
  }

  void createSession(String projectId, {String? workflowId}) {
    final project = _projectById(projectId);
    final session = Session(
      id: generateUuidV4(),
      title: kDefaultSessionTitle,
      createdAt: DateTime.now(),
      // Sin elección, el de siempre. Elegir otro es un click en el hilo, y
      // solo mientras no arrancó.
      workflowId: workflowId ?? project?.activeWorkflowId ?? '',
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
    _activeSessionRuns.remove(sessionId);
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

  /// Si la sesión sigue marcada como detenida. Un turno nuevo no puede
  /// arrancar mientras lo esté: `_runTurn` corta en su primera guarda.
  bool isSessionStopped(String sessionId) =>
      _stoppedSessionIds.contains(sessionId);

  /// Frena el turno en curso. Con [interrupting] la sesión NO se sella como
  /// fallida: es un mensaje del usuario que entra a mitad de nodo, y el
  /// workflow retoma ese nodo cuando el mensaje se atendió. Sin esto un
  /// mensaje de interrupción sellaba `failed`, dejaba el nodo `running` y
  /// nadie volvía a `_runWorkflow`: el flujo moría por escribirle.
  void stopSession(
    String projectId,
    String sessionId, {
    bool interrupting = false,
  }) {
    final run = _runningSessions.remove(sessionId);
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    // Entre turno y turno no hay TaskRun vivo, pero la corrida sigue. Sin
    // registrar el id igual, Stop en esa ventana era un botón que no hacía
    // nada — y un fan-out de consultas no se podía cortar.
    if (run == null && !(session?.isRunning ?? false)) return;

    _stoppedSessionIds.add(sessionId);
    _cancelBlockingDecisions(projectId, sessionId);
    run?.cancel();
    _releaseRunningNodes(projectId, sessionId);

    if (interrupting) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.system,
          text:
              'Turno interrumpido para atender tu mensaje. El workflow '
              'retoma el paso en curso cuando lo haya atendido.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

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

  void _releaseRunningNodes(String projectId, String sessionId) {
    final project = _projectById(projectId);
    final resolution = project == null
        ? null
        : _sessionById(project, sessionId)?.resolutionCase;
    if (resolution == null) return;
    _storeResolution(
      projectId,
      sessionId,
      ResolutionEngine.releaseRunningNodes(resolution),
    );
  }

  /// Retoma un workflow que quedó a mitad —por una interrupción con mensaje
  /// o por una decisión que ya se contestó— si tiene un nodo listo.
  Future<void> resumeWorkflow(String projectId, String sessionId) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final resolution = session?.resolutionCase;
    if (session == null || resolution == null) return;
    if (session.isRunning || _activeSessionRuns.contains(sessionId)) return;
    if (!resolution.preflight.ready) return;
    if (resolution.status != ResolutionCaseStatus.active) return;
    if (_nextReadyNode(resolution) == null) return;
    await _runWorkflow(projectId, sessionId, session.request);
  }

  /// Runs an adaptive workflow. Nodes are selected by dependencies and fresh
  /// evidence, never by a positional list of agents.
  Future<void> _runWorkflow(
    String projectId,
    String sessionId,
    String request,
  ) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final workflow = session == null ? null : workflowOf(session);
    if (project == null || session == null || workflow == null) {
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text: 'Esta sesión no tiene un workflow adaptativo seleccionado.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    await Future.wait([
      AgentProfilesService.instance.notifier.ready,
      SkillsService.instance.notifier.ready,
      RulesService.instance.notifier.ready,
      KnowledgeService.instance.notifier.ready,
      SecretsService.instance.notifier.ready,
    ]);
    final preflight = _adaptivePreflight(project, session, workflow);
    if (preflight.error != null || preflight.owner == null) {
      final blocked =
          ResolutionEngine.start(
            id: session.resolutionCase?.id ?? generateUuidV4(),
            kind: workflow.kind,
            ownerRole:
                preflight.owner?.role ?? workflow.policy.resolutionRole.trim(),
            capabilities: workflow.capabilities,
            ownerProfileIds: {
              for (final entry in preflight.nodeOwners.entries)
                entry.key: entry.value.id,
            },
          ).copyWith(
            status: ResolutionCaseStatus.blocked,
            preflight: preflight.preflight,
          );
      _updateSession(
        projectId,
        sessionId,
        (open) => open.copyWith(
          request: open.request.isEmpty ? request : open.request,
          resolutionCase: blocked,
        ),
      );
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text: 'Preflight bloqueado: ${preflight.error}',
          timestamp: DateTime.now(),
        ),
      );
      _finishSession(projectId, sessionId, SessionStatus.failed);
      await _persist();
      return;
    }

    final existingResolution = session.resolutionCase;
    var resolution =
        (existingResolution == null || !existingResolution.preflight.ready
            ? null
            : existingResolution) ??
        ResolutionEngine.start(
          id: generateUuidV4(),
          kind: workflow.kind,
          ownerRole: preflight.owner!.role,
          capabilities: workflow.capabilities,
          ownerProfileIds: {
            for (final entry in preflight.nodeOwners.entries)
              entry.key: entry.value.id,
          },
        ).copyWith(preflight: preflight.preflight);
    _updateSession(
      projectId,
      sessionId,
      (open) => open.copyWith(
        isRunning: true,
        request: open.request.isEmpty ? request : open.request,
        resolutionCase: resolution,
      ),
    );
    _activeSessionRuns.add(sessionId);
    _stoppedSessionIds.remove(sessionId);
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.system,
        text: _preflightSummary(workflow, preflight.owner!),
        timestamp: DateTime.now(),
      ),
    );

    final workflowTurnId = generateUuidV4();
    try {
      while (!_stoppedSessionIds.contains(sessionId)) {
        // El techo de costo se mira ANTES de elegir nodo: un nodo que ya no
        // entra en el presupuesto no arranca, y lo que le queda al que sí
        // arranca viaja al CLI para que corte solo.
        final costCeiling = workflow.policy.maxSessionCostUsd;
        final spentUsd =
            _sessionById(
              _projectById(projectId) ?? project,
              sessionId,
            )?.usage.reportedCostUsd ??
            0;
        if (costCeiling > 0 && spentUsd >= costCeiling) {
          resolution = resolution.copyWith(
            status: ResolutionCaseStatus.blocked,
          );
          _storeResolution(projectId, sessionId, resolution);
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.error,
              text:
                  'Techo de costo de la sesión alcanzado: US\$ '
                  '${spentUsd.toStringAsFixed(2)} de '
                  '${costCeiling.toStringAsFixed(2)}. El caso queda '
                  'bloqueado; subí el techo en la policy del workflow o '
                  'abrí una sesión nueva.',
              timestamp: DateTime.now(),
            ),
          );
          _finishSession(projectId, sessionId, SessionStatus.failed);
          break;
        }
        final remainingBudgetUsd = costCeiling > 0
            ? costCeiling - spentUsd
            : 0.0;

        final node = _nextReadyNode(resolution);
        if (node == null) {
          if (ResolutionEngine.canComplete(resolution)) {
            _storeResolution(
              projectId,
              sessionId,
              resolution.copyWith(status: ResolutionCaseStatus.completed),
            );
            _finishSession(projectId, sessionId, SessionStatus.finished);
          } else {
            _appendMessage(
              projectId,
              sessionId,
              ChatMessage(
                role: ChatRole.error,
                text:
                    'El caso no cierra: quedan gates, evidencia o cobertura '
                    'de migración sin registrar.',
                timestamp: DateTime.now(),
              ),
            );
            _finishSession(projectId, sessionId, SessionStatus.failed);
          }
          break;
        }

        resolution = _replaceNode(resolution, node.id, WorkNodeStatus.running);
        _storeResolution(projectId, sessionId, resolution);
        final nodeOwner =
            preflight.nodeOwners[node.id] ??
            membersOf(
              project,
              session: session,
            ).where((member) => member.id == node.ownerProfileId).firstOrNull ??
            preflight.owner!;
        final capability = _capabilityFor(workflow, node.id);
        if (capability.executor == WorkflowExecutor.manualApproval) {
          resolution = _replaceNode(resolution, node.id, WorkNodeStatus.paused);
          _storeResolution(projectId, sessionId, resolution);
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text:
                  'El workflow está listo para publicar. Aprobá el paso '
                  '"${node.title}" para continuar.',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
          return;
        }

        // La aprobación es una decisión sobre el paso, no un paso más: el
        // nodo queda pausado y esperándote hasta que la contestás.
        if (capability.approvalRequired) {
          final decisions =
              _sessionById(_projectById(projectId) ?? project, sessionId)
                  ?.decisions ??
              const <SessionDecision>[];
          final approvals = decisions.where(
            (decision) =>
                decision.kind == SessionDecisionKind.approval &&
                decision.workNodeId == node.id,
          );
          final granted = approvals.any(
            (decision) => decision.status == SessionDecisionStatus.granted,
          );
          if (!granted) {
            resolution = _replaceNode(resolution, node.id, WorkNodeStatus.paused);
            _storeResolution(projectId, sessionId, resolution);
            if (!approvals.any((decision) => decision.isPending)) {
              _enqueueDecision(
                projectId,
                sessionId,
                SessionDecision(
                  id: generateUuidV4(),
                  kind: SessionDecisionKind.approval,
                  profileId: nodeOwner.id,
                  workNodeId: node.id,
                  title: 'Aprobar el paso "${node.title.isEmpty ? node.id : node.title}"',
                  detail: node.instruction.length > 400
                      ? '${node.instruction.substring(0, 400)}…'
                      : node.instruction,
                  createdAt: DateTime.now(),
                ),
                memberName: nodeOwner.name,
              );
            }
            await _persist();
            return;
          }
        }

        if (capability.executor == WorkflowExecutor.providerSubagent) {
          if (resolution.reviewCycleCount >= workflow.policy.maxReviewCycles) {
            resolution = resolution.copyWith(
              status: ResolutionCaseStatus.blocked,
            );
            _storeResolution(projectId, sessionId, resolution);
            _appendMessage(
              projectId,
              sessionId,
              ChatMessage(
                role: ChatRole.error,
                text:
                    'Se alcanzó el máximo de ${workflow.policy.maxReviewCycles} '
                    'ciclos de auditoría; revisá el caso manualmente.',
                timestamp: DateTime.now(),
                workNodeId: node.id,
              ),
            );
            // Sellado: antes salía con la sesión en `running` y nada
            // corriendo, que es una sesión trabada sin señal.
            _finishSession(projectId, sessionId, SessionStatus.failed);
            return;
          }
          resolution = resolution.copyWith(
            reviewCycleCount: resolution.reviewCycleCount + 1,
          );
          _storeResolution(projectId, sessionId, resolution);
        }

        // El `project` de arriba es un snapshot tomado ANTES de `_updateSession`,
        // así que su sesión todavía tiene el `request` vacío de recién creada:
        // hay que releer el proyecto acá. Y un request vacío NO es `null`, así
        // que `??` nunca lo cubría — de ahí el chequeo explícito de vacío. Sin
        // las dos cosas, el PRIMER nodo de una sesión nueva recibía
        // "Pedido original:" en blanco y se quedaba sin caso que resolver.
        final freshProject = _projectById(projectId);
        final storedRequest = freshProject == null
            ? null
            : _sessionById(freshProject, sessionId)?.request;
        final isAudit = capability.outputContract == 'audit-feedback';
        // Lo que dejaron las dependencias viaja en la instrucción: es la
        // diferencia entre seguir el trabajo y volver a descubrir el repo.
        // El resumen del caso va cuando hay nodos cerrados que no son
        // dependencias directas: lo que las salidas directas no cuentan.
        final outputs = dependencyOutputs(resolution, node);
        final hasIndirectHistory = resolution.nodes.any(
          (entry) =>
              entry.status == WorkNodeStatus.done &&
              !node.dependencyIds.contains(entry.id),
        );
        final nodePrompt = adaptiveNodePrompt(
          request: storedRequest == null || storedRequest.isEmpty
              ? request
              : storedRequest,
          workflow: workflow,
          resolution: resolution,
          node: node,
          isAudit: isAudit,
          dependencyContext: renderDependencyOutputs(outputs),
          digest: hasIndirectHistory ? sessionDigest(resolution) : '',
        );
        // Lo que el usuario contestó a este nodo viaja en la instrucción: la
        // sesión del CLI se reanuda con el prompt nuevo, no lee el hilo.
        final answers = [
          for (final decision
              in freshProject == null
                  ? const <SessionDecision>[]
                  : _sessionById(freshProject, sessionId)?.decisions ??
                        const <SessionDecision>[])
            if (decision.workNodeId == node.id &&
                decision.kind != SessionDecisionKind.approval &&
                decision.status == SessionDecisionStatus.answered)
              '- Pediste: ${decision.detail}\n  Respuesta: ${decision.answer}',
        ];
        final baseInstruction = answers.isEmpty
            ? nodePrompt
            : '$nodePrompt\n\nRESPUESTAS DEL USUARIO a lo que pediste antes '
                  '(seguí con esto, no vuelvas a preguntar lo mismo):\n'
                  '${answers.join('\n')}';
        var outcome = await _runWorkflowCapability(
          projectId: projectId,
          sessionId: sessionId,
          workflow: workflow,
          capability: capability,
          resolution: resolution,
          node: node,
          nodeOwner: nodeOwner,
          instruction: baseInstruction,
          turnId: workflowTurnId,
          preflight: preflight,
          maxBudgetUsd: remainingBudgetUsd,
        );
        // Un Stop o una interrupción a mitad de nodo no es evidencia de
        // nada: el nodo ya volvió a `pending` y el caso sigue activo. Seguir
        // acá lo registraba como hallazgo del compilador y lo pausaba, con
        // lo que ni el retome lo encontraba listo.
        if (_stoppedSessionIds.contains(sessionId)) break;
        // A turn may have registered migration coverage while it ran. Reload
        // the graph so a stale local snapshot cannot overwrite that evidence.
        resolution =
            _sessionById(
              _projectById(projectId) ?? project,
              sessionId,
            )?.resolutionCase ??
            resolution;
        // Un turno que cerró sin el bloque (o una auditoría sin veredicto)
        // recibe UN seguimiento: un turno de un paso sobre la misma sesión
        // que solo pide el estado. Barato, y evita adivinar.
        if (outcome.ok && !_outcomeIsComplete(outcome.report, isAudit)) {
          outcome = await _runWorkflowCapability(
            projectId: projectId,
            sessionId: sessionId,
            workflow: workflow,
            capability: capability,
            resolution: resolution,
            node: node,
            nodeOwner: nodeOwner,
            instruction: baseInstruction,
            turnId: workflowTurnId,
            preflight: preflight,
            maxBudgetUsd: remainingBudgetUsd,
            followUp: true,
          );
          if (_stoppedSessionIds.contains(sessionId)) break;
          resolution =
              _sessionById(
                _projectById(projectId) ?? project,
                sessionId,
              )?.resolutionCase ??
              resolution;
        }

        if (!outcome.ok) {
          final registration = ResolutionEngine.reportFinding(
            resolution,
            evidence: ResolutionEvidence(
              id: generateUuidV4(),
              source: ResolutionEvidenceSource.compiler,
              summary: outcome.answer.trim().isEmpty
                  ? 'El turno del nodo falló sin respuesta.'
                  : outcome.answer.trim(),
              fingerprint: '${node.id}:${normalizeForMatch(outcome.answer)}',
              createdAt: DateTime.now(),
            ),
            affectedNodeId: node.id,
            maxReplans: workflow.policy.maxReplans,
          );
          resolution = registration.resolution;
          if (!registration.accepted) {
            resolution = resolution.copyWith(
              status: ResolutionCaseStatus.blocked,
            );
          } else if (resolution.status != ResolutionCaseStatus.blocked) {
            resolution = _replaceNode(
              resolution.copyWith(status: ResolutionCaseStatus.active),
              node.id,
              WorkNodeStatus.pending,
            );
          }
          _storeResolution(projectId, sessionId, resolution);
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.error,
              text: resolution.status == ResolutionCaseStatus.blocked
                  ? 'Caso bloqueado: el nodo "${node.title}" falló dos veces '
                        'con la misma evidencia.'
                  : 'El turno del nodo "${node.title}" falló; se reintenta.',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
          if (resolution.status == ResolutionCaseStatus.blocked) {
            _finishSession(projectId, sessionId, SessionStatus.failed);
            break;
          }
          continue;
        }

        // Sin bloque ni después del seguimiento: si habló, se toma lo que
        // dijo como cierre; si calló del todo, se bloquea con motivo.
        final report =
            outcome.report ??
            TurnOutcomeReport(
              status: outcome.answer.trim().isEmpty
                  ? TurnOutcomeStatus.blocked
                  : TurnOutcomeStatus.done,
              summary: outcome.answer.trim().isEmpty
                  ? 'El nodo terminó sin bloque keel-outcome y sin texto.'
                  : _excerpt(outcome.answer, 600),
            );
        final effectiveReport =
            isAudit &&
                report.status == TurnOutcomeStatus.done &&
                report.verdict == null
            ? TurnOutcomeReport(
                status: TurnOutcomeStatus.blocked,
                summary:
                    'La auditoría cerró sin veredicto GO/NO-GO. '
                    '${report.summary}',
                files: report.files,
                artifacts: report.artifacts,
              )
            : report;
        final application = ResolutionEngine.applyOutcome(
          resolution,
          nodeId: node.id,
          report: effectiveReport,
          isAudit: isAudit,
          parentNodeId: capability.parentCapabilityId.trim(),
          maxReplans: workflow.policy.maxReplans,
          profileId: nodeOwner.id,
          now: DateTime.now(),
          newId: generateUuidV4,
        );
        resolution = application.resolution;
        _storeResolution(projectId, sessionId, resolution);

        final toActivate = application.activateCapabilityId;
        if (toActivate != null) {
          final error = await activateWorkflowCapability(
            projectId,
            sessionId,
            toActivate,
          );
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text: error == null
                  ? 'El nodo "${node.title}" activó la capacidad opcional '
                        '"$toActivate".'
                  : 'El nodo "${node.title}" pidió activar "$toActivate": '
                        '$error',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
          resolution =
              _sessionById(
                _projectById(projectId) ?? project,
                sessionId,
              )?.resolutionCase ??
              resolution;
        }

        final decision = application.decision;
        if (decision != null) {
          _enqueueDecision(
            projectId,
            sessionId,
            decision,
            memberName: nodeOwner.name,
          );
          await _persist();
          return;
        }

        if (resolution.status == ResolutionCaseStatus.blocked) {
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.error,
              text:
                  'Caso bloqueado en "${node.title}": '
                  '${effectiveReport.summary}',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
          _finishSession(projectId, sessionId, SessionStatus.failed);
          break;
        }
        if (isAudit && effectiveReport.verdict == TurnVerdict.noGo) {
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text:
                  'NO-GO de "${node.title}": vuelve el nodo auditado con el '
                  'hallazgo; la auditoría re-corre después de la corrección '
                  '(ciclo ${resolution.reviewCycleCount} de '
                  '${workflow.policy.maxReviewCycles}).',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
        } else if (effectiveReport.status == TurnOutcomeStatus.blocked ||
            effectiveReport.status == TurnOutcomeStatus.failed) {
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text:
                  'El nodo "${node.title}" declaró ${effectiveReport.status.name}: '
                  '${effectiveReport.summary}. Se reintenta con el hallazgo.',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      await _abandonRun(projectId, sessionId, error, stackTrace);
    } finally {
      await _settleSessionRunAndDispatch(projectId, sessionId);
    }
  }

  /// Un bloque alcanza si existe y, en un nodo de auditoría, trae veredicto.
  bool _outcomeIsComplete(TurnOutcomeReport? report, bool isAudit) {
    if (report == null) return false;
    if (!isAudit) return true;
    if (report.status != TurnOutcomeStatus.done) return true;
    return report.verdict != null;
  }

  String _excerpt(String text, int max) {
    final trimmed = text.trim();
    return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max)}…';
  }

  void _enqueueDecision(
    String projectId,
    String sessionId,
    SessionDecision decision, {
    required String memberName,
  }) {
    _updateSession(
      projectId,
      sessionId,
      (session) =>
          session.copyWith(decisions: [...session.decisions, decision]),
    );
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.system,
        text: switch (decision.kind) {
          SessionDecisionKind.question =>
            '@$memberName necesita tu respuesta: ${decision.detail}',
          SessionDecisionKind.permission =>
            '@$memberName necesita un permiso: ${decision.detail}',
          SessionDecisionKind.approval =>
            '${decision.title}: el paso espera tu aprobación.',
        },
        timestamp: DateTime.now(),
        workNodeId: decision.workNodeId,
      ),
    );
  }

  // ── decisiones bloqueantes: gate de permisos y ask_user ─────────────

  /// Lo que contesta el gate antes de una tool que escribe. Si el permiso ya
  /// está concedido —para la app, para este agente acá, o para esta
  /// sesión— contesta al instante; si no, encola una decisión y ESPERA a
  /// que la persona la conteste. El proceso del CLI queda suspendido en el
  /// hook mientras tanto; el vigilante del turno se pausa.
  Future<({bool allow, String reason})> decideToolUse({
    required String projectId,
    required String sessionId,
    required String profileId,
    required String toolName,
    required String toolInput,
  }) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (project == null || session == null) {
      return (allow: false, reason: 'Keel no reconoce esta sesión.');
    }
    if (_isToolGranted(project, session, profileId, toolName)) {
      return (allow: true, reason: '');
    }
    if (_stoppedSessionIds.contains(sessionId)) {
      return (allow: false, reason: 'El turno fue detenido.');
    }
    final member = membersOf(project, session: session)
        .where((entry) => entry.id == profileId)
        .firstOrNull;
    final resolved = await _awaitDecision(
      projectId,
      sessionId,
      SessionDecision(
        id: generateUuidV4(),
        kind: SessionDecisionKind.permission,
        profileId: profileId,
        workNodeId: _activeWorkNodeId(session) ?? '',
        title: 'Quiere usar $toolName',
        detail: toolInput,
        toolName: toolName,
        toolInput: toolInput,
        blocking: true,
        createdAt: DateTime.now(),
      ),
      memberName: member?.name ?? 'agente',
    );
    return switch (resolved.status) {
      SessionDecisionStatus.granted => (allow: true, reason: ''),
      SessionDecisionStatus.cancelled => (
        allow: false,
        reason: 'El turno fue detenido antes de que se decidiera.',
      ),
      _ => (
        allow: false,
        reason:
            'La persona rechazó $toolName'
            '${resolved.answer.isEmpty ? '.' : ': ${resolved.answer}'}',
      ),
    };
  }

  /// `ask_user`: una pregunta que suspende el turno hasta la respuesta.
  Future<String> askUser({
    required String projectId,
    required String sessionId,
    required String profileId,
    required String question,
    List<String> options = const [],
  }) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (project == null || session == null) {
      return 'Keel no reconoce esta sesión; no hay a quién preguntarle.';
    }
    if (_stoppedSessionIds.contains(sessionId)) {
      return 'El turno fue detenido.';
    }
    final member = membersOf(project, session: session)
        .where((entry) => entry.id == profileId)
        .firstOrNull;
    final resolved = await _awaitDecision(
      projectId,
      sessionId,
      SessionDecision(
        id: generateUuidV4(),
        kind: SessionDecisionKind.question,
        profileId: profileId,
        workNodeId: _activeWorkNodeId(session) ?? '',
        title: 'Necesita una decisión tuya',
        detail: question,
        options: options,
        blocking: true,
        createdAt: DateTime.now(),
      ),
      memberName: member?.name ?? 'agente',
    );
    return switch (resolved.status) {
      SessionDecisionStatus.answered => resolved.answer,
      SessionDecisionStatus.cancelled =>
        'La persona detuvo el turno sin contestar.',
      _ => 'La persona no contestó (${resolved.status.name}).',
    };
  }

  bool _isToolGranted(
    Project project,
    Session session,
    String profileId,
    String toolName,
  ) =>
      SettingsService.instance.notifier.data.extraAllowedTools.contains(
        toolName,
      ) ||
      (project.grantedToolsByProfileId[profileId] ?? const []).contains(
        toolName,
      ) ||
      session.grantedTools.contains(toolName);

  Future<SessionDecision> _awaitDecision(
    String projectId,
    String sessionId,
    SessionDecision decision, {
    required String memberName,
  }) async {
    final completer = Completer<SessionDecision>();
    _gateCompleters[decision.id] = completer;
    _enqueueDecision(projectId, sessionId, decision, memberName: memberName);
    // Esperar a una persona no es inactividad del agente.
    for (final watchdog in _turnWatchdogs[sessionId] ?? const <TurnWatchdog>{}) {
      watchdog.pause();
    }
    unawaited(_persist());
    try {
      return await completer.future;
    } finally {
      _gateCompleters.remove(decision.id);
      for (final watchdog
          in _turnWatchdogs[sessionId] ?? const <TurnWatchdog>{}) {
        watchdog.resume();
      }
    }
  }

  void _cancelBlockingDecisions(String projectId, String sessionId) {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (session == null) return;
    final cancelled = <SessionDecision>[];
    _updateSession(
      projectId,
      sessionId,
      (open) => open.copyWith(
        decisions: [
          for (final decision in open.decisions)
            if (decision.isPending && _gateCompleters.containsKey(decision.id))
              (() {
                final done = decision.copyWith(
                  status: SessionDecisionStatus.cancelled,
                  resolvedAt: DateTime.now(),
                );
                cancelled.add(done);
                return done;
              })()
            else
              decision,
        ],
      ),
    );
    for (final decision in cancelled) {
      _gateCompleters.remove(decision.id)?.complete(decision);
    }
  }

  void _recordGrant(
    String projectId,
    String sessionId,
    String profileId,
    String toolName,
    String scope,
  ) {
    switch (scope) {
      case 'session':
        _updateSession(
          projectId,
          sessionId,
          (open) => open.copyWith(
            grantedTools: {...open.grantedTools, toolName}.toList(),
          ),
        );
      case 'profile':
        _updateProject(projectId, (project) {
          final grants = Map<String, List<String>>.from(
            project.grantedToolsByProfileId,
          );
          grants[profileId] = {...?grants[profileId], toolName}.toList();
          return project.copyWith(grantedToolsByProfileId: grants);
        });
      case 'app':
        SettingsService.instance.notifier.setExtraToolEnabled(toolName, true);
      default:
        break;
    }
  }

  /// Tu respuesta a una decisión pendiente.
  ///
  /// Dos caminos según quién espera. Si hay un turno VIVO suspendido (gate o
  /// `ask_user`), se le completa la espera y el proceso sigue; [scope] dice
  /// hasta dónde vale un permiso concedido: once | session | profile | app.
  /// Si no —el nodo cerró con `needs_user` o pide aprobación— se destraba el
  /// nodo, se deja la respuesta en el hilo y se retoma el workflow.
  Future<String?> answerSessionDecision(
    String projectId,
    String sessionId,
    String decisionId, {
    String answer = '',
    bool? approve,
    String scope = 'once',
  }) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final decision = session?.decisions
        .where((entry) => entry.id == decisionId && entry.isPending)
        .firstOrNull;
    if (project == null || session == null || decision == null) {
      return 'Esa decisión ya no está pendiente.';
    }

    final waiting = _gateCompleters[decisionId];
    if (waiting != null) {
      final isPermission = decision.kind == SessionDecisionKind.permission;
      if (isPermission && approve == null) return 'Falta conceder o rechazar.';
      if (!isPermission && answer.trim().isEmpty) {
        return 'La respuesta está vacía.';
      }
      final resolved = decision.copyWith(
        status: isPermission
            ? (approve!
                  ? SessionDecisionStatus.granted
                  : SessionDecisionStatus.denied)
            : SessionDecisionStatus.answered,
        answer: answer.trim(),
        scope: scope,
        resolvedAt: DateTime.now(),
      );
      _updateSession(
        projectId,
        sessionId,
        (open) => open.copyWith(
          decisions: [
            for (final entry in open.decisions)
              entry.id == decisionId ? resolved : entry,
          ],
        ),
      );
      if (isPermission && approve!) {
        _recordGrant(
          projectId,
          sessionId,
          decision.profileId,
          decision.toolName,
          scope,
        );
      }
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.user,
          text: isPermission
              ? (approve!
                    ? 'Permitido ${decision.toolName} (${_scopeLabel(scope)}).'
                    : 'Rechazado ${decision.toolName}.')
              : answer.trim(),
          timestamp: DateTime.now(),
          workNodeId: decision.workNodeId.isEmpty ? null : decision.workNodeId,
        ),
      );
      await _persist();
      waiting.complete(resolved);
      return null;
    }

    final isApproval = decision.kind == SessionDecisionKind.approval;
    if (isApproval && approve == null) return 'Falta aprobar o rechazar.';
    if (!isApproval && answer.trim().isEmpty) return 'La respuesta está vacía.';

    final resolved = decision.copyWith(
      status: isApproval
          ? (approve! ? SessionDecisionStatus.granted : SessionDecisionStatus.denied)
          : SessionDecisionStatus.answered,
      answer: answer.trim(),
      resolvedAt: DateTime.now(),
    );
    _updateSession(
      projectId,
      sessionId,
      (open) => open.copyWith(
        decisions: [
          for (final entry in open.decisions)
            entry.id == decisionId ? resolved : entry,
        ],
      ),
    );

    final resolution = _sessionById(project, sessionId)?.resolutionCase;
    if (resolution != null) {
      if (isApproval && approve == false) {
        final blocked = _replaceNode(
          resolution.copyWith(status: ResolutionCaseStatus.blocked),
          decision.workNodeId,
          WorkNodeStatus.blocked,
        );
        _storeResolution(projectId, sessionId, blocked);
        _appendMessage(
          projectId,
          sessionId,
          ChatMessage(
            role: ChatRole.error,
            text: 'Rechazaste el paso "${decision.title}". El caso queda '
                'bloqueado ahí.',
            timestamp: DateTime.now(),
            workNodeId: decision.workNodeId,
          ),
        );
        _finishSession(projectId, sessionId, SessionStatus.failed);
        await _persist();
        return null;
      }
      _storeResolution(
        projectId,
        sessionId,
        _replaceNode(
          resolution.copyWith(status: ResolutionCaseStatus.active),
          decision.workNodeId,
          WorkNodeStatus.pending,
        ),
      );
    }
    final member = membersOf(project, session: session)
        .where((entry) => entry.id == decision.profileId)
        .firstOrNull;
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.user,
        text: isApproval
            ? 'Aprobado: ${decision.title}'
            : '@${member?.name ?? 'agente'} ${answer.trim()}',
        timestamp: DateTime.now(),
        workNodeId: decision.workNodeId,
      ),
    );
    await _persist();
    await resumeWorkflow(projectId, sessionId);
    return null;
  }

  static String _scopeLabel(String scope) => switch (scope) {
    'session' => 'esta sesión',
    'profile' => 'este agente en este proyecto',
    'app' => 'siempre',
    _ => 'solo esta vez',
  };

  WorkflowCapability _capabilityFor(Workflow workflow, String nodeId) {
    final capabilities = workflow.capabilities.isEmpty
        ? defaultWorkflowCapabilities(
            workflow.kind,
            workflow.policy.resolutionRole,
          )
        : workflow.capabilities;
    return capabilities.firstWhere((capability) => capability.id == nodeId);
  }

  String _workflowExecutionId(String sessionId, String capabilityId) =>
      'workflow:$sessionId:$capabilityId';

  Future<TurnOutcome> _runWorkflowCapability({
    required String projectId,
    required String sessionId,
    required Workflow workflow,
    required WorkflowCapability capability,
    required ResolutionCase resolution,
    required WorkNode node,
    required AgentProfile nodeOwner,
    required String instruction,
    required String turnId,
    required _AdaptivePreflightResult preflight,
    double maxBudgetUsd = 0,

    /// El seguimiento de un turno que cerró sin bloque: UN turno sobre la
    /// misma sesión que solo pide el estado. No trabaja, no consulta.
    bool followUp = false,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return (ok: false, answer: 'Proyecto no disponible.', report: null);

    final parentId = capability.parentCapabilityId.trim();
    final parentNode = parentId.isEmpty
        ? null
        : resolution.nodes.where((entry) => entry.id == parentId).firstOrNull;
    final parentOwner = parentNode == null
        ? null
        : preflight.nodeOwners[parentId] ??
              membersOf(project, session: _sessionById(project, sessionId))
                  .where((member) => member.id == parentNode.ownerProfileId)
                  .firstOrNull;
    final reports = _auditReportsFor(
      project,
      sessionId,
      node.dependencyIds,
      workflow,
    );
    final effectiveInstruction = followUp
        ? kOutcomeFollowUpPrompt
        : reports.isEmpty
        ? instruction
        : '$instruction\n\nINFORMES DE AUDITORÍA A RESOLVER:\n$reports';
    final turnCap = followUp ? 1 : capability.effectiveMaxAgenticTurns;

    switch (capability.executor) {
      case WorkflowExecutor.newSession:
        // El mismo dueño que ya cerró una dependencia reanuda ESA sesión:
        // no vuelve a leer el repo que ya leyó. Determinista a propósito,
        // así el seguimiento de un turno cae en la misma sesión que él.
        final liveIds =
            _sessionById(project, sessionId)?.cliSessionsByExecutionId.keys
                .toSet() ??
            const <String>{};
        final reuseFrom = !workflow.policy.reuseOwnerSession
            ? null
            : reusableDependencyId(
                node: node,
                nodes: resolution.nodes,
                ownerId: nodeOwner.id,
                ownerIdOf: (id) =>
                    preflight.nodeOwners[id]?.id ??
                    resolution.nodes
                        .where((entry) => entry.id == id)
                        .firstOrNull
                        ?.ownerProfileId ??
                    '',
                liveExecutionIds: liveIds,
                executionIdFor: (id) => _workflowExecutionId(sessionId, id),
                requiresIndependentOwner: capability.requiresIndependentOwner,
              );
        final executionId = _workflowExecutionId(
          sessionId,
          reuseFrom ?? capability.id,
        );
        if (reuseFrom != null && !followUp) {
          final compacted = _compactIfNeeded(
            projectId,
            sessionId,
            executionId,
            workflow.policy,
          );
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text: compacted
                  ? 'El nodo "${node.title}" arranca fresco con el resumen '
                        'del caso: el contexto de la sesión de "$reuseFrom" '
                        'superó el umbral de compactación.'
                  : 'El nodo "${node.title}" reanuda la sesión de '
                        '"$reuseFrom" (mismo agente): no vuelve a leer lo '
                        'que ya leyó.',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
        }
        return _runTurn(
          projectId: projectId,
          sessionId: sessionId,
          member: nodeOwner,
          workNodeId: node.id,
          instruction: effectiveInstruction,
          consultOfProfileId: null,
          turnId: turnId,
          depth: 0,
          allowConsults: !followUp,
          executionId: executionId,
          maxTurns: turnCap,
          maxBudgetUsd: maxBudgetUsd,
          planMode: capability.readOnly,
        );
      case WorkflowExecutor.resumeParent:
        if (parentOwner == null) {
          return (ok: false, answer: 'No se encontró la sesión padre.', report: null);
        }
        if (!followUp) {
          _compactIfNeeded(
            projectId,
            sessionId,
            _workflowExecutionId(sessionId, parentId),
            workflow.policy,
          );
        }
        return _runTurn(
          projectId: projectId,
          sessionId: sessionId,
          member: parentOwner,
          workNodeId: node.id,
          instruction: effectiveInstruction,
          consultOfProfileId: null,
          turnId: turnId,
          depth: 0,
          allowConsults: !followUp,
          executionId: _workflowExecutionId(sessionId, parentId),
          maxTurns: turnCap,
          maxBudgetUsd: maxBudgetUsd,
        );
      case WorkflowExecutor.providerSubagent:
        if (parentOwner == null) {
          return (ok: false, answer: 'No se encontró el padre del auditor.', report: null);
        }
        if (followUp) {
          // El estado se le pide a la sesión que de verdad auditó: la
          // externa del fallback si existe, si no la del padre.
          final externalId = _workflowExecutionId(sessionId, capability.id);
          final usedExternal =
              _sessionById(project, sessionId)?.cliSessionsByExecutionId
                  .containsKey(externalId) ??
              false;
          return _runTurn(
            projectId: projectId,
            sessionId: sessionId,
            member: usedExternal ? nodeOwner : parentOwner,
            workNodeId: node.id,
            instruction: kOutcomeFollowUpPrompt,
            consultOfProfileId: usedExternal ? parentOwner.id : null,
            turnId: turnId,
            depth: 0,
            allowConsults: false,
            executionId: usedExternal
                ? externalId
                : _workflowExecutionId(sessionId, parentId),
            maxTurns: 1,
            maxBudgetUsd: maxBudgetUsd,
            planMode: usedExternal && capability.readOnly,
          );
        }
        final packet = _subagentPacket(
          project: project,
          sessionId: sessionId,
          node: node,
          target: nodeOwner,
          instruction: effectiveInstruction,
        );
        final parentEngine = project.tuned(parentOwner);
        if (parentEngine.provider == AgentProvider.claude) {
          final before =
              _sessionById(project, sessionId)?.subagents.length ?? 0;
          final native = await _runTurn(
            projectId: projectId,
            sessionId: sessionId,
            member: parentOwner,
            workNodeId: node.id,
            instruction:
                '$packet\n\nAbrí exactamente un subagente nativo '
                'Task para esta auditoría. No escribas archivos; sintetizá su '
                'informe completo al finalizar.',
            consultOfProfileId: null,
            turnId: turnId,
            depth: 0,
            allowConsults: false,
            executionId: _workflowExecutionId(sessionId, parentId),
            maxTurns: capability.effectiveMaxAgenticTurns,
          maxBudgetUsd: maxBudgetUsd,
          );
          final after = _sessionById(project, sessionId)?.subagents.length ?? 0;
          if (after > before) return native;
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text:
                  'Claude no abrió el subagente solicitado; se usa la '
                  'sesión externa de @${nodeOwner.name}.',
              timestamp: DateTime.now(),
              workNodeId: node.id,
            ),
          );
        }
        return _runTurn(
          projectId: projectId,
          sessionId: sessionId,
          member: nodeOwner,
          workNodeId: node.id,
          instruction: packet,
          consultOfProfileId: parentOwner.id,
          turnId: turnId,
          depth: 0,
          allowConsults: false,
          executionId: _workflowExecutionId(sessionId, capability.id),
          maxTurns: capability.effectiveMaxAgenticTurns,
          maxBudgetUsd: maxBudgetUsd,
          // El modo del NODO, no «plan» a secas: con `planMode: true` fijo,
          // un nodo de entrega (commit, push, PR) que cayera en esta rama no
          // podía escribir nunca y quemaba su tope explicando por qué.
          planMode: capability.readOnly,
        );
      case WorkflowExecutor.manualApproval:
        return (ok: false, answer: 'El paso requiere aprobación manual.', report: null);
    }
  }

  String _auditReportsFor(
    Project project,
    String sessionId,
    List<String> dependencyIds,
    Workflow workflow,
  ) {
    final auditIds = {
      for (final dependency in dependencyIds)
        if (_capabilityFor(workflow, dependency).outputContract ==
            'audit-feedback')
          dependency,
    };
    if (auditIds.isEmpty) return '';
    final session = _sessionById(project, sessionId);
    // Lo que el auditor DECLARÓ en su bloque de cierre va primero: es corto
    // y es lo que el motor evaluó. El hilo entero queda como respaldo para
    // nodos que cerraron antes de que el bloque existiera.
    final declared = [
      for (final node in session?.resolutionCase?.nodes ?? const <WorkNode>[])
        if (auditIds.contains(node.id) &&
            (node.output?.summary.trim().isNotEmpty ?? false))
          '[${node.title.isEmpty ? node.id : node.title}] '
              '${node.output!.verdict == null ? '' : 'Veredicto: ${node.output!.verdict == TurnVerdict.go ? 'GO' : 'NO-GO'}. '}'
              '${node.output!.summary.trim()}'
              '${node.output!.files.isEmpty ? '' : '\nArchivos: ${node.output!.files.join(', ')}'}',
    ];
    if (declared.isNotEmpty) return declared.join('\n\n');
    final messages = session?.messages ?? const [];
    return messages
        .where(
          (message) =>
              message.role == ChatRole.assistant &&
              auditIds.contains(message.workNodeId),
        )
        .map((message) => message.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }

  /// Si el contexto de la sesión pasó el umbral de la policy, descarta la
  /// sesión del CLI en [executionId]: el próximo turno arranca fresco con el
  /// resumen del caso en la instrucción. Sin LLM: el resumen ES la
  /// compactación. Devuelve si compactó.
  bool _compactIfNeeded(
    String projectId,
    String sessionId,
    String executionId,
    WorkflowPolicy policy,
  ) {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (session == null) return false;
    if (!session.cliSessionsByExecutionId.containsKey(executionId)) {
      return false;
    }
    final ratio = session.contextUsageRatio ?? 0;
    if (ratio < policy.compactAtContextRatio) return false;
    _updateSession(projectId, sessionId, (open) {
      final sessions = Map<String, String>.from(open.cliSessionsByExecutionId)
        ..remove(executionId);
      return open.copyWith(cliSessionsByExecutionId: sessions);
    });
    Log.i(
      'Compactación: sesión $executionId descartada con contexto al '
      '${(ratio * 100).round()}%',
    );
    return true;
  }

  String _subagentPacket({
    required Project project,
    required String sessionId,
    required WorkNode node,
    required AgentProfile target,
    required String instruction,
  }) {
    // Sin skills, reglas ni system prompt del auditor: cuando la auditoría
    // cae a la sesión externa, todo eso ya viaja como SU system prompt, y
    // repetirlo acá lo mandaba dos veces (hasta 12k chars de instrucción).
    // Cuando corre como subagente nativo, el padre ya tiene las skills del
    // workflow. El paquete es el contrato y los archivos, nada más.
    final changed =
        _sessionById(project, sessionId)?.messages
            .where((message) => message.fileEdits.isNotEmpty)
            .expand((message) => message.fileEdits)
            .map((edit) => edit.path)
            .toSet()
            .join(', ') ??
        '';
    final packet =
        'AUDITOR DESTINO: @${target.name} (${target.role})\n'
        'Modo: solo lectura. No edites archivos.\n'
        'Contrato de salida: veredicto, todos los hallazgos, evidencia, '
        'archivo/línea y acción sugerida.\n'
        'Archivos modificados conocidos: ${changed.isEmpty ? 'no disponibles' : changed}.\n\n'
        '$instruction';
    return packet.length <= 8000 ? packet : '${packet.substring(0, 8000)}…';
  }

  Future<void> _abandonRun(
    String projectId,
    String sessionId,
    Object error,
    StackTrace stackTrace,
  ) async {
    Log.e(
      'La resolución adaptativa se cortó',
      error: error,
      stackTrace: stackTrace,
    );
    _runningSessions.remove(sessionId);
    _stoppedSessionIds.remove(sessionId);
    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: ChatRole.error,
        text: 'El caso se detuvo por un error inesperado: $error',
        timestamp: DateTime.now(),
      ),
    );
    _finishSession(projectId, sessionId, SessionStatus.failed);
    await _persist();
  }

  _AdaptivePreflightResult _adaptivePreflight(
    Project project,
    Session session,
    Workflow workflow,
  ) {
    final skills = SkillsService.instance.notifier.data.skills;
    final requiredSkills = {
      ...workflow.skillNames,
      ...workflow.policy.requiredSkillNames,
    };
    final missingSkills = requiredSkills
        .where(
          (name) => !skills.any(
            (skill) => skill.name == name && skill.content.isNotEmpty,
          ),
        )
        .toList();
    final rules = RulesService.instance.notifier.data.rules;
    final missingRules = workflow.policy.requiredRuleNames
        .where(
          (name) => !rules.any(
            (rule) => rule.name == name && rule.content.isNotEmpty,
          ),
        )
        .toList();
    final bases = KnowledgeService.instance.notifier.data.bases;
    final missingKnowledge = workflow.policy.requiredKnowledgeBaseNames
        .where((name) => !bases.any((base) => base.name == name))
        .toList();
    final members = membersOf(project, session: session);
    final role = workflow.policy.resolutionRole.trim();
    final owner = role.isEmpty
        ? members.firstOrNull
        : _memberForRole(project, role, session: session);
    final nodeOwners = <String, AgentProfile>{};
    final missingAgents = <String>[];
    final missingSecrets = <String>[];
    final capabilities = workflow.capabilities.isEmpty
        ? defaultWorkflowCapabilities(
            workflow.kind,
            workflow.policy.resolutionRole,
          )
        : workflow.capabilities;
    for (final capability in capabilities.where(
      (entry) => entry.activation == WorkflowCapabilityActivation.required,
    )) {
      final overrideId = project.assignedProfileId(workflow.id, capability.id);
      final assigned = overrideId == null
          ? memberForRole(members, capability.role)
          : members.where((member) => member.id == overrideId).firstOrNull;
      final nodeOwner = assigned ?? (capability.role == '*' ? owner : null);
      if (nodeOwner == null) {
        missingAgents.add('${capability.title}: ${capability.role}');
        continue;
      }
      nodeOwners[capability.id] = nodeOwner;
      final engine = project.tuned(nodeOwner);
      final secretName = engine.provider.secretName;
      if (secretName != null &&
          (SecretsService.instance.notifier.pendingOf([
                secretName,
              ]).isNotEmpty ||
              SecretsService.instance.notifier.missingOf([
                secretName,
              ]).isNotEmpty)) {
        missingSecrets.add(secretName);
      }
    }
    for (final capability in capabilities.where(
      (entry) =>
          entry.activation == WorkflowCapabilityActivation.required &&
          entry.requiresIndependentOwner,
    )) {
      final nodeOwner = nodeOwners[capability.id];
      if (nodeOwner == null) continue;
      final dependencyOwnerIds = capability.dependencyIds
          .map((id) => nodeOwners[id]?.id)
          .whereType<String>()
          .toSet();
      if (dependencyOwnerIds.contains(nodeOwner.id)) {
        missingAgents.add(
          '${capability.title}: requiere un agente independiente de sus dependencias',
        );
      }
    }
    if (owner == null) {
      missingAgents.insert(
        0,
        'responsable: ${role.isEmpty ? 'sin asignar' : role}',
      );
    }
    final preflight = ResolutionPreflight(
      performed: true,
      injectedSkills: requiredSkills
          .where((name) => !missingSkills.contains(name))
          .toList(),
      injectedRules: {
        ...project.ruleNames,
        ...workflow.policy.requiredRuleNames,
      }.where((name) => !missingRules.contains(name)).toList(),
      injectedKnowledge: {
        ...project.knowledgeBaseNames,
        ...workflow.policy.requiredKnowledgeBaseNames,
      }.where((name) => !missingKnowledge.contains(name)).toList(),
      missingSkills: missingSkills,
      missingRules: missingRules,
      missingKnowledge: missingKnowledge,
      missingAgents: missingAgents,
      missingSecrets: missingSecrets.toSet().toList(),
    );
    return _AdaptivePreflightResult(
      owner: owner,
      nodeOwners: nodeOwners,
      preflight: preflight,
    );
  }

  String _preflightSummary(Workflow workflow, AgentProfile owner) {
    final skillNames = {
      ...workflow.skillNames,
      ...workflow.policy.requiredSkillNames,
    }.join(', ');
    final ruleNames = workflow.policy.requiredRuleNames.join(', ');
    final knowledgeNames = workflow.policy.requiredKnowledgeBaseNames.join(
      ', ',
    );
    return 'Preflight listo · workflow ${workflow.name} · responsable '
        '@${owner.name} · skills ${skillNames.isEmpty ? 'ninguna' : skillNames} '
        '· reglas ${ruleNames.isEmpty ? 'ninguna' : ruleNames} '
        '· conocimiento ${knowledgeNames.isEmpty ? 'ninguno' : knowledgeNames} '
        '· gates '
        '${workflow.policy.qualityGates.map((gate) => gate.name).join(', ')} '
        '· topes ${_policyLimitsSummary(workflow.policy)}.';
  }

  /// Los topes con los que corre la sesión, dichos de entrada: que un nodo se
  /// corte a los N minutos no puede ser una sorpresa al final.
  String _policyLimitsSummary(WorkflowPolicy policy) {
    final ceiling = policy.maxSessionCostUsd > 0
        ? 'US\$ ${policy.maxSessionCostUsd.toStringAsFixed(0)} por sesión '
              '(solo cuenta el costo que el proveedor informa; codex no lo '
              'informa)'
        : 'sin techo de costo';
    return '${policy.idleTimeoutMinutes} min sin actividad · '
        '${policy.nodeTimeoutMinutes} min por paso · $ceiling';
  }

  WorkNode? _nextReadyNode(ResolutionCase resolution) {
    for (final node in resolution.nodes) {
      if (node.status != WorkNodeStatus.pending) continue;
      final ready = node.dependencyIds.every(
        (id) => resolution.nodes.any(
          (candidate) =>
              candidate.id == id && candidate.status == WorkNodeStatus.done,
        ),
      );
      if (ready) return node;
    }
    return null;
  }

  ResolutionCase _replaceNode(
    ResolutionCase resolution,
    String nodeId,
    WorkNodeStatus status,
  ) => resolution.copyWith(
    nodes: [
      for (final node in resolution.nodes)
        node.id == nodeId ? node.copyWith(status: status) : node,
    ],
  );

  void _storeResolution(
    String projectId,
    String sessionId,
    ResolutionCase resolution,
  ) {
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(resolutionCase: resolution),
    );
  }

  /// Prende o apaga el modo plan de una sesión: sus turnos proponen y no
  /// tocan nada. Aplica al turno de un miembro, no al ciclo de workflow —
  /// un workflow entero planificado igual llegaría a cerrar la sesión.
  void setSessionPlanMode(String projectId, String sessionId, bool enabled) {
    _updateSession(
      projectId,
      sessionId,
      (session) =>
          session.copyWith(planMode: enabled, planAwaitingDecision: false),
    );
    unawaited(_persist());
  }

  /// El plan quedó aprobado: sale del modo plan y manda a implementarlo.
  ///
  /// El plan viaja escrito adentro del mensaje y no solo en el `--resume`:
  /// si la sesión del CLI murió y hay que reintentar sin ella, un agente que
  /// lee «implementá lo acordado» sin saber qué se acordó implementa
  /// cualquier cosa, en silencio.
  Future<void> implementSessionPlan(String projectId, String sessionId) async {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (session == null || !session.planAwaitingDecision) return;

    final plan = session.messages
        .where((message) => message.role == ChatRole.assistant)
        .lastOrNull
        ?.text
        .trim();

    _updateSession(
      projectId,
      sessionId,
      (session) =>
          session.copyWith(planMode: false, planAwaitingDecision: false),
    );
    await _persist();

    await _sendToSession(projectId, sessionId, planApprovalRequest(plan));
  }

  /// Baja la tarjeta y deja el modo plan prendido.
  void keepPlanningSession(String projectId, String sessionId) {
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(planAwaitingDecision: false),
    );
  }

  /// What the composer calls. Everything it does happens **inside the session
  /// that is already open** — it never creates one. The first message of a
  /// session kicks off the workflow; every message after that is a follow-up to
  /// the agent that is holding the work.
  Future<void> sendToChannel(
    String projectId,
    String text, {
    List<String> imagePaths = const [],
  }) async {
    final project = _projectById(projectId);
    final session = project?.activeSession;
    if (project == null || session == null) return;
    await _sendToSession(projectId, session.id, text, imagePaths: imagePaths);
  }

  /// Contesta, adentro de una sesión que ya existe, un mensaje concreto de
  /// esa sesión. Es lo que llama la tool `reply_in_session` de Keel AI
  /// después de que el usuario dijo «respondele».
  ///
  /// Entra por la MISMA vía que el compositor: si la sesión está corriendo el
  /// mensaje se encola y sale como el turno siguiente. Lo único distinto es
  /// que queda marcado como puesto por Keel AI.
  Future<void> replyInSession(
    String projectId,
    String sessionId,
    String text,
  ) => _sendToSession(projectId, sessionId, text, viaKeelAi: true);

  Future<void> _sendToSession(
    String projectId,
    String sessionId,
    String text, {
    List<String> imagePaths = const [],
    bool viaKeelAi = false,
  }) async {
    final trimmedForInsights = text.trim();
    if (trimmedForInsights.isNotEmpty) {
      // Zero-token recurrence detector — never in the send critical path.
      unawaited(
        PromptInsightsService.instance.notifier.record(trimmedForInsights),
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePaths.isEmpty) return;

    var project = _projectById(projectId);
    if (project == null) return;

    var session = _sessionById(project, sessionId);
    if (session == null) return;
    if (session.isRunning || _preparingSessionTurns.contains(sessionId)) {
      await queueSessionMessage(
        projectId,
        sessionId,
        trimmed,
        imagePaths: imagePaths,
        viaKeelAi: viaKeelAi,
      );
      return;
    }

    final started = session.messages.any(
      (message) => message.role == ChatRole.assistant,
    );
    if (!started) {
      // Lock the workflow choice immediately. Resolving a linked directory or
      // knowledge document is asynchronous, but the first request has already
      // started from the user's point of view.
      _updateSession(
        projectId,
        session.id,
        (open) => open.title == kDefaultSessionTitle
            ? open.copyWith(
                title: _titleFor(
                  trimmed.isEmpty ? 'Imágenes adjuntas' : trimmed,
                ),
              )
            : open,
      );
      _appendMessage(
        projectId,
        session.id,
        ChatMessage(
          role: ChatRole.user,
          text: trimmed,
          timestamp: DateTime.now(),
          imagePaths: imagePaths,
          viaKeelAi: viaKeelAi,
        ),
      );
    }

    _preparingSessionTurns.add(sessionId);
    late final String explicitContext;
    try {
      explicitContext = await ChatReferenceService.promptContext(
        ProjectReferenceScope(
          project: project,
          members: membersOf(project, session: session),
        ),
        trimmed,
      );
    } finally {
      _preparingSessionTurns.remove(sessionId);
    }
    project = _projectById(projectId);
    if (project == null) return;
    session = _sessionById(project, sessionId);
    if (session == null) return;
    if (session.isRunning) {
      if (started) {
        await queueSessionMessage(
          projectId,
          sessionId,
          trimmed,
          imagePaths: imagePaths,
          viaKeelAi: viaKeelAi,
        );
      }
      return;
    }
    final prompt = [
      if (trimmed.isNotEmpty) trimmed,
      if (explicitContext.isNotEmpty) explicitContext,
      if (imagePaths.isNotEmpty) _describeChannelAttachments(imagePaths),
    ].join('\n\n');

    if (!started) {
      return _runWorkflow(projectId, session.id, prompt);
    }

    _appendMessage(
      projectId,
      session.id,
      ChatMessage(
        role: ChatRole.user,
        text: trimmed,
        timestamp: DateTime.now(),
        imagePaths: imagePaths,
        viaKeelAi: viaKeelAi,
      ),
    );
    final members = membersOf(project, session: session);
    final member =
        ChatReferenceService.explicitlyMentionedMember(trimmed, members) ??
        _followUpOwner(project, session);
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
    await _runMemberTurn(
      projectId: projectId,
      sessionId: session.id,
      member: member,
      workNodeId: _activeWorkNodeId(session),
      instruction: prompt,
    );
    // Si el mensaje interrumpió un nodo, el nodo volvió a `pending` y el
    // caso sigue activo: el workflow lo retoma acá, no lo hace nadie más.
    await resumeWorkflow(projectId, session.id);
  }

  /// Guarda un mensaje bajo control del usuario mientras la sesión trabaja.
  /// No intenta escribir dentro del stdin de un CLI one-shot.
  Future<String?> queueSessionMessage(
    String projectId,
    String sessionId,
    String text, {
    List<String> imagePaths = const [],
    bool viaKeelAi = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePaths.isEmpty) return null;
    final id = generateUuidV4();
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        queuedMessages: [
          ...session.queuedMessages,
          SessionQueuedMessage(
            id: id,
            text: trimmed,
            imagePaths: [...imagePaths],
            createdAt: DateTime.now(),
            viaKeelAi: viaKeelAi,
          ),
        ],
      ),
    );
    await _persist();
    return id;
  }

  Future<void> editQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
    String text,
  ) async {
    final trimmed = text.trim();
    _replaceQueuedSessionMessage(
      projectId,
      sessionId,
      messageId,
      (message) => trimmed.isEmpty && message.imagePaths.isEmpty
          ? message
          : message.copyWith(text: trimmed),
    );
    await _persist();
  }

  Future<void> removeQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
  ) async {
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        queuedMessages: [
          for (final message in session.queuedMessages)
            if (message.id != messageId) message,
        ],
      ),
    );
    await _persist();
  }

  Future<void> holdQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
  ) async {
    _setQueuedDelivery(
      projectId,
      sessionId,
      messageId,
      SessionQueuedDelivery.standby,
    );
    await _persist();
  }

  Future<void> sendQueuedSessionMessageAfterTurn(
    String projectId,
    String sessionId,
    String messageId,
  ) async {
    _setQueuedDelivery(
      projectId,
      sessionId,
      messageId,
      SessionQueuedDelivery.afterCurrentTurn,
    );
    await _persist();
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (!(session?.isRunning ?? false)) {
      await _dispatchNextQueuedMessage(projectId, sessionId);
    }
  }

  /// Interrumpe el turno en curso, pero espera a que su Future realmente
  /// termine antes de abrir el siguiente. Así dos agentes nunca escriben el
  /// workspace al mismo tiempo por una carrera entre Stop y Send.
  Future<void> sendQueuedSessionMessageNow(
    String projectId,
    String sessionId,
    String messageId,
  ) async {
    _setQueuedDelivery(
      projectId,
      sessionId,
      messageId,
      SessionQueuedDelivery.interrupting,
    );
    await _persist();

    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final isStillQueued = session?.queuedMessages.any(
      (message) => message.id == messageId,
    );
    // The old turn may have settled while persistence yielded. Its finalizer
    // then already dispatched this exact message; stopping here would cancel
    // the new turn we intended to start.
    if (isStillQueued != true) return;
    if (session?.isRunning ?? false) {
      final activeRunWillDispatch = _activeSessionRuns.contains(sessionId);
      stopSession(projectId, sessionId, interrupting: true);
      if (activeRunWillDispatch) return;
    }
    await _dispatchNextQueuedMessage(projectId, sessionId);
  }

  void _setQueuedDelivery(
    String projectId,
    String sessionId,
    String messageId,
    SessionQueuedDelivery delivery,
  ) {
    _replaceQueuedSessionMessage(
      projectId,
      sessionId,
      messageId,
      (message) => message.copyWith(delivery: delivery),
    );
  }

  void _replaceQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
    SessionQueuedMessage Function(SessionQueuedMessage message) replace,
  ) {
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        queuedMessages: [
          for (final message in session.queuedMessages)
            if (message.id == messageId) replace(message) else message,
        ],
      ),
    );
  }

  String _describeChannelAttachments(List<String> imagePaths) {
    final buffer = StringBuffer(
      'El usuario adjuntó imágenes a este mensaje. Leelas con una herramienta '
      'de lectura antes de responder:',
    );
    for (final path in imagePaths) {
      buffer.write('\n- $path');
    }
    return buffer.toString();
  }

  /// A member hit a tool it is not allowed to use. The CLI runs headless, so
  /// it cannot stop and ask — it just denies and keeps going, often several
  /// times in the same turn. So the session asks *once*, on your behalf, and
  /// remembers who was blocked in order to resume them if you say yes.
  void _handlePermissionDenied({
    required String projectId,
    required String sessionId,
    required AgentProfile member,
    required String? workNodeId,
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
          workNodeId: workNodeId,
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
      workNodeId: _activeWorkNodeId(session),
      instruction:
          'Ya tenés permiso para usar ${request.toolName}. Retomá lo que '
          'estabas haciendo desde donde te quedaste.',
    );
  }

  /// Saca del hilo una tarjeta que solo AVISA, sin conceder ni rechazar nada.
  ///
  /// Es para el bloqueo de un hook: ahí no hay turno suspendido esperando —el
  /// CLI ya denegó y siguió—, así que descartarla no le debe nada a nadie.
  /// Como [Session.pendingPermission] es el único lugar donde vive la
  /// tarjeta, limpiarla es lo que hace que el descarte se mantenga cuando el
  /// hilo se vuelve a construir.
  void dismissSessionPermission(String projectId, String sessionId) {
    _permissionBlockedProfileBySession.remove(sessionId);
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(clearPendingPermission: true),
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
      workNodeId: _activeWorkNodeId(session),
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
      workNodeId: _activeWorkNodeId(session),
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
    required String? workNodeId,
    required String instruction,
  }) async {
    // El modo de la sesión se lee ANTES de arrancar: es el modo con el que
    // este turno corre, y decide si al final hay algo que preguntar.
    final startProject = _projectById(projectId);
    final planMode = startProject == null
        ? false
        : _sessionById(startProject, sessionId)?.planMode ?? false;

    _activeSessionRuns.add(sessionId);
    _stoppedSessionIds.remove(sessionId);
    _updateSession(
      projectId,
      sessionId,
      // Mandar algo reemplaza la decisión anterior: si había una tarjeta de
      // «¿implementamos?», el mensaje nuevo es la respuesta.
      (session) =>
          session.copyWith(isRunning: true, planAwaitingDecision: false),
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
        workNodeId: workNodeId,
        instruction: instruction,
        consultOfProfileId: null,
        turnId: generateUuidV4(),
        depth: 0,
        planMode: planMode,
      );
    } finally {
      await _settleSessionRunAndDispatch(
        projectId,
        sessionId,
        planned: planMode,
      );
    }
  }

  Future<void> _settleSessionRunAndDispatch(
    String projectId,
    String sessionId, {
    bool planned = false,
  }) async {
    final stopped = _stoppedSessionIds.contains(sessionId);
    _runningSessions.remove(sessionId);
    _stoppedSessionIds.remove(sessionId);
    _activeSessionRuns.remove(sessionId);
    _purgeConsultLedgerIfIdle();
    // El turno planificó y llegó al final solo: hay algo que decidir. Si lo
    // frenaron a mano, no: parar es tomar el control, no pedir permiso.
    final settleProject = _projectById(projectId);
    final settleSession = settleProject == null
        ? null
        : _sessionById(settleProject, sessionId);
    final lastReport = settleSession?.messages.reversed
        .where((message) => message.role == ChatRole.assistant)
        .map((message) => parseKeelOutcome(message.text))
        .firstOrNull;
    final awaiting = shouldAskToImplement(
      planMode: planned,
      stopped: stopped,
      // Llegar acá con el turno terminado ya es haber contestado: el hilo de
      // la sesión guarda la respuesta antes de que el turno se asiente.
      hasAnswer: true,
      hasQueuedMessages:
          settleSession == null || settleSession.queuedMessages.isNotEmpty,
      askedUser:
          (settleSession?.waitingForUser ?? false) ||
          lastReport?.status == TurnOutcomeStatus.needsUser ||
          lastReport?.status == TurnOutcomeStatus.needsPermission,
    );
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        isRunning: false,
        clearLiveTurn: true,
        planAwaitingDecision: awaiting,
      ),
    );
    await _persist();
    await _dispatchNextQueuedMessage(projectId, sessionId);
  }

  Future<void> _dispatchNextQueuedMessage(
    String projectId,
    String sessionId,
  ) async {
    if (_activeSessionRuns.contains(sessionId)) return;
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (session == null || session.isRunning) return;

    SessionQueuedMessage? next;
    for (final message in session.queuedMessages) {
      if (message.delivery == SessionQueuedDelivery.interrupting) {
        next = message;
        break;
      }
    }
    next ??= session.queuedMessages
        .where(
          (message) =>
              message.delivery == SessionQueuedDelivery.afterCurrentTurn,
        )
        .firstOrNull;
    if (next == null) return;

    _updateSession(
      projectId,
      sessionId,
      (open) => open.copyWith(
        queuedMessages: [
          for (final message in open.queuedMessages)
            if (message.id != next!.id) message,
        ],
      ),
    );
    // La marca de «detenido» es del turno que se frenó, no de la sesión. Acá
    // el mensaje YA salió de la cola: si la marca sobrevive, `_runTurn` corta
    // en su primera guarda y el mensaje se pierde para siempre — aparece en
    // el hilo, no lo lee nadie, y el usuario lo tiene que escribir de nuevo.
    // La corrida de workflow lo limpiaba en su `finally`; una sesión sin
    // workflow no tenía quién.
    // La marca de «detenido» es del turno que se frenó, no de la sesión. Acá
    // el mensaje YA salió de la cola: si la marca sobrevive, `_runTurn` corta
    // en su primera guarda y el mensaje se pierde para siempre — aparece en
    // el hilo, no lo lee nadie, y el usuario lo tiene que escribir de nuevo.
    // La corrida de workflow lo limpiaba en su `finally`; una sesión sin
    // workflow no tenía quién.
    _stoppedSessionIds.remove(sessionId);
    await _persist();
    await _sendToSession(
      projectId,
      sessionId,
      next.text,
      imagePaths: next.imagePaths,
      viaKeelAi: next.viaKeelAi,
    );
  }

  /// Follow-ups return to the resolution owner, then to the last author.
  AgentProfile? _followUpOwner(Project project, Session session) {
    final ownerRole = session.resolutionCase?.ownerRole.trim();
    if (ownerRole != null && ownerRole.isNotEmpty) {
      final owner = _memberForRole(project, ownerRole, session: session);
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

  /// Muda un proyecto de carpeta.
  ///
  /// Dos usos, los dos legítimos: completar la ruta de un proyecto que llegó
  /// sin ella (el respaldo saca las rutas a propósito — son de esta máquina),
  /// y seguir a un worktree que se unificó en el principal, donde la carpeta
  /// vieja directamente dejó de existir.
  void setProjectWorkingDirectory(String id, String path) {
    _updateProject(id, (project) => project.copyWith(workingDirectory: path));
    unawaited(_persist());
    unawaited(_rememberRoot(path));
  }

  /// La carpeta de un proyecto es, por definición, un lugar donde este
  /// usuario trabaja: entra a las raíces conocidas para que el próximo
  /// selector abra ahí y para que un agente sin proyecto sepa que existe —
  /// aunque esté en otro disco.
  Future<void> _rememberRoot(String path) =>
      WorkspaceRootsService.instance.notifier.remember(path);

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
    required String? workNodeId,
    required String instruction,
    required String? consultOfProfileId,
    required String turnId,
    required int depth,
    String? executionId,
    int maxTurns = 0,
    double maxBudgetUsd = 0,
    bool allowConsults = true,
    bool retriedWithoutSession = false,

    /// Apagado por defecto A PROPÓSITO: solo el turno de un miembro lo
    /// prende. Un ciclo de workflow entero corrido en modo plan llegaría
    /// igual a `_finishSession` y sellaría la sesión como terminada sin
    /// haber escrito una línea.
    bool planMode = false,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return (ok: false, answer: '', report: null);
    if (_stoppedSessionIds.contains(sessionId)) return (ok: false, answer: '', report: null);

    // The current user request is delivered as `prompt` below. Everything
    // before it is reconstructed for remote APIs; removing that final user
    // entry avoids sending it twice to the provider.
    final messagesBeforeCurrentTurn = [
      ...?_sessionById(project, sessionId)?.messages,
    ];
    if (messagesBeforeCurrentTurn.lastOrNull?.role == ChatRole.user) {
      messagesBeforeCurrentTurn.removeLast();
    }
    // La firma del hilo va con HANDLE, no con id: el system prompt le
    // promete al agente que "los mensajes vienen firmados con el handle de
    // quien los escribió" y `authorProfileId` es un UUID. Firmando con el id
    // la promesa se rompe en silencio y el agente no puede seguir quién dijo
    // qué en un canal de varios.
    final threadMembers = membersOf(
      project,
      session: _sessionById(project, sessionId),
    );
    final conversationHistory = remoteConversationHistory(
      messagesBeforeCurrentTurn,
      includeAssistantAuthor: true,
      handleOf: (profileId) => threadMembers
          .where((candidate) => candidate.id == profileId)
          .firstOrNull
          ?.name,
    );

    final effectiveExecutionId = executionId ?? 'member:${member.id}';
    final cliSessionId = _sessionById(
      project,
      sessionId,
    )?.cliSessionsByExecutionId[effectiveExecutionId];
    final collector = FileEditCollector(
      workingDirectory: project.workingDirectory,
    );
    final reasoning = StringBuffer();
    final answer = StringBuffer();
    var turnFailed = false;
    var sessionConfirmed = false;
    var failureMessage = '';
    // El tope de turnos no es una falla: es un número que se quedó corto.
    // El motor le pide al nodo cómo quedó en vez de registrar un hallazgo.
    var capHit = false;

    // El mapa de las bases se arma leyendo el disco: si el catálogo todavía
    // no cargó, el turno saldría sin saber que existen. Acá sí se puede
    // esperar — `_turnSystemPrompt` es síncrono a propósito.
    // El MAPA de las bases, no solo el catálogo: sin índice el agente no
    // ve qué hay adentro de sus bases de saber. Es el único lugar donde
    // vale la pena esperar el recorrido del disco.
    await KnowledgeService.instance.notifier.indexReady;

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
    // El gate de permisos: un hook PreToolUse que suspende el proceso hasta
    // que la persona decide. Con el gate puesto, las tools que escriben
    // entran a la allow-list del CLI —si no, el CLI las deniega solo, sin
    // preguntar— y es el gate el que decide. Un proyecto que no mantenés
    // sigue sin tools de escritura, y una consulta también.
    await DecisionGateServer.ensureStarted();
    final gate = (consultOfProfileId != null || !project.maintained)
        ? null
        : DecisionGateServer.gateSpecFor(
            projectId: projectId,
            sessionId: sessionId,
            profileId: member.id,
          );
    final askEntry = (isCodex || consultOfProfileId != null)
        ? null
        : DecisionGateServer.mcpServerEntryFor(
            projectId: projectId,
            sessionId: sessionId,
            profileId: member.id,
          );
    // El roadmap del PROYECTO, distinto del plan de la sesión: uno dura meses
    // y vive en el repo, el otro dura una tarde y vive en el canal. Solo
    // aparece si el proyecto tiene carpeta TASKS/ — sin eso, tres tools que
    // no aplican.
    // Los requerimientos hacia otros proyectos. Igual que el roadmap: no van
    // a codex (no recibe MCPs) ni a un turno de consulta, que contesta y se va.
    final requirementsEntry = (isCodex || consultOfProfileId != null)
        ? null
        : RequirementsMcpServer.mcpServerEntryFor(
            projectId: projectId,
            sessionId: sessionId,
            profileId: member.id,
          );

    // Un turno de CONSULTA sí recibe el roadmap, en modo lectura. Antes no
    // recibía nada, y el efecto era el peor posible: al auditor —que casi
    // siempre habla consultado— le aparecía "keel-roadmap desconectado"
    // justo cuando le pedían verificar el roadmap, y contestaba lo único
    // honesto que podía: que no tenía con qué.
    final isConsult = consultOfProfileId != null;
    final turnWorkflow = _workflowRunning(project, sessionId);
    final roadmapEntry = isCodex
        ? null
        : RoadmapMcpServer.mcpServerEntryFor(
            sessionId: sessionId,
            projectId: projectId,
            profileId: member.id,
            workingDirectory: project.workingDirectory,
            readOnly: isConsult,
            // El workflow que CONSTRUYE la carpeta todavía no la tiene: es
            // justo el que necesita poder chequearla mientras la arma.
            evenWithoutFolder: turnWorkflow?.buildsRoadmap ?? false,
          );
    // Los tableros de prueba. Un turno de consulta tampoco los recibe: viene
    // a contestar una pregunta y se va, y dejarle armar una UI en el
    // proyecto de otro es exactamente la clase de efecto lateral que una
    // consulta no debería tener.
    final boardsEntry = (isCodex || isConsult)
        ? null
        : BoardsMcpServer.mcpServerEntryFor(
            projectId: projectId,
            sessionId: sessionId,
            profileId: member.id,
          );

    final mcpServers = <String, dynamic>{
      kUserToolsMcpServerKey: ?toolsEntry,
      kSessionPlanMcpServerKey: ?planEntry,
      kDecisionsMcpServerKey: ?askEntry,
      kRoadmapMcpServerKey: ?roadmapEntry,
      kRequirementsMcpServerKey: ?requirementsEntry,
      kBoardsMcpServerKey: ?boardsEntry,
      for (final server in externalServers)
        server.name: server.toMcpServerEntry(externalSecretValues),
    };

    // La ENTREGA (PR en draft) solo aplica donde hay repo, y DÓNDE está
    // parado el repo cambia lo que hay que pedirle al agente.
    //
    // Antes esto era `Directory('$dir/.git').existsSync()`, y fallaba en dos
    // casos: en un worktree de al lado `.git` es un ARCHIVO que apunta al
    // principal, y en una subcarpeta del repo no está. En los dos daba falso,
    // y con eso el agente no recibía la sección de entrega — la parte que le
    // dice que abra el PR. Preguntarle a git es la respuesta correcta en los
    // tres casos.
    final place = await WorktreeService.instance.notifier.ensure(
      project.workingDirectory,
    );
    final usesGit = place.isRepo;

    // Codex recibe el system prompt solo en el PRIMER turno de su sesión: en
    // turnos resumidos el estado del plan quedaría congelado en el turno 1.
    // El estado vivo viaja antepuesto al pedido, que sí llega siempre.
    final effectiveInstruction = (isCodex && cliSessionId != null)
        ? [
            planSectionPrompt(
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
    final turnHooks = await _resolveTurnHooks(project, engine, gate: gate);
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
    final providerApiKey = await SecretsService.instance.notifier.resolveValue(
      engine.provider.secretName,
    );

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
          if (gate != null) ...kDecisionGateTools,
          if (askEntry != null) ...kDecisionsMcpToolNames,
          if (planEntry != null) ...kSessionPlanMcpToolNames,
          if (roadmapEntry != null)
            ...(isConsult
                ? kRoadmapMcpReadOnlyToolNames
                : kRoadmapMcpToolNames),
          if (requirementsEntry != null) ...kRequirementsMcpToolNames,
          if (boardsEntry != null) ...kBoardsMcpToolNames,
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
          place: place,
          usesGithubMcp: externalServers.any(isGithubMcpServer),
          // Codex no tiene system prompt: en un resume el preámbulo se
          // repite, así que va la versión compacta (identidad, reglas,
          // contratos) y no las skills ni el saber, que ya están en su hilo.
          compact: isCodex && cliSessionId != null,
        ),
        mcpConfig: mcpServers.isEmpty
            ? null
            : jsonEncode({'mcpServers': mcpServers}),
        hooksSettings: turnHooks.claudeSettings,
        hooksConfig: turnHooks.codexConfig,
        hookFiles: turnHooks.files,
        conversationHistory: conversationHistory,
        planMode: planMode,
        maxTurns: maxTurns,
        maxBudgetUsd: maxBudgetUsd,
        provider: engine.provider.alias,
        providerApiKey: providerApiKey,
      ),
    );
    _runningSessions[sessionId] = run;
    // The channel is shared, so the live strip has to say *who* is working.
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        liveTurn: SessionLiveTurn(
          profileId: member.id,
          consultOfProfileId: consultOfProfileId,
        ),
      ),
    );

    // El pid del CLI de este turno. Se anota para que la pantalla de Máquina
    // pueda decir de parte de quién corre cada proceso, y se suelta al
    // terminar: una lista que no se limpia es una lista que miente.
    var livePid = 0;
    final streamTimestamp = DateTime.now();
    final runPolicy = _workflowRunning(project, sessionId)?.policy;
    final maxSubagents = runPolicy?.maxSubagents ?? 0;
    // Un CLI mudo no termina solo. El vigilante corta el proceso y cierra el
    // stream: el `await for` de abajo sale como si el proveedor hubiera
    // terminado, y el turno se marca fallido con el motivo puesto.
    final watchdog = TurnWatchdog(
      idle: Duration(
        minutes: runPolicy?.idleTimeoutMinutes ?? kDefaultIdleTimeoutMinutes,
      ),
      hard: Duration(
        minutes: runPolicy?.nodeTimeoutMinutes ?? kDefaultNodeTimeoutMinutes,
      ),
      onTrip: (_) => run.cancel(),
    );
    _turnWatchdogs.putIfAbsent(sessionId, () => {}).add(watchdog);
    var subagentLimitExceeded = false;
    // Ver la fila sin medición más abajo: [turnMeasured] evita anotar dos
    // veces y [providerEngaged] evita anotar un turno que murió antes de
    // gastar un token.
    var turnMeasured = false;
    var providerEngaged = false;
    final turnStartedAt = DateTime.now();

    await for (final event in watchdog.guard(run.events)) {
      if (_stoppedSessionIds.contains(sessionId)) break;

      switch (event) {
        case TaskProcessStarted(pid: final pid):
          livePid = pid;
          RunningProcesses.register(
            pid,
            '${project.name} · '
            '${_sessionById(project, sessionId)?.title ?? 'sesión'}',
          );

        case TaskSessionStarted(sessionId: final id):
          sessionConfirmed = true;
          providerEngaged = true;
          _updateSession(projectId, sessionId, (session) {
            final sessions = Map<String, String>.from(
              session.cliSessionsByExecutionId,
            );
            sessions[effectiveExecutionId] = id;
            return session.copyWith(cliSessionsByExecutionId: sessions);
          });

        case TaskAssistantText(text: final chunk):
          providerEngaged = true;
          answer.write(chunk);
          _appendStreamingAssistantMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.assistant,
              text: chunk,
              timestamp: streamTimestamp,
              reasoning: reasoning.isEmpty ? null : reasoning.toString(),
              fileEdits: await collector.collect(),
              authorProfileId: member.id,
              workNodeId: workNodeId,
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

        case TaskSubagentStarted(
          id: final id,
          agentType: final agentType,
          ask: final ask,
          prompt: final prompt,
        ):
          // Cuando llega este evento el CLI YA abrió el subagente: no hay
          // forma de impedirlo, solo de cancelar la corrida entera. Cancelar
          // mataba el nodo con todo su trabajo ya hecho —producción migrada,
          // tests a medio adaptar— por un tope que el propio contrato del
          // workflow le pedía superar. Así que el tope avisa UNA vez y el
          // turno sigue; el subagente se registra igual, porque nada de lo
          // que hace un agente puede quedar invisible en el mapa.
          if (!_subagentBudget.tryReserve(
                turnId: turnId,
                workNodeId: workNodeId,
                maxSubagents: maxSubagents,
              ) &&
              !subagentLimitExceeded) {
            subagentLimitExceeded = true;
            _appendMessage(
              projectId,
              sessionId,
              ChatMessage(
                role: ChatRole.system,
                text:
                    'Este nodo se pasó de los $maxSubagents subagente(s) que '
                    'permite el workflow. Se registran igual para que queden '
                    'visibles, pero revisá el contrato: su instrucción está '
                    'pidiendo más delegación de la que su política habilita.',
                timestamp: DateTime.now(),
                workNodeId: workNodeId,
              ),
            );
          }
          _updateSession(
            projectId,
            sessionId,
            (session) => session.copyWith(
              subagents: [
                ...session.subagents,
                SessionSubagent(
                  id: id,
                  parentProfileId: member.id,
                  parentWorkNodeId: workNodeId,
                  agentType: agentType,
                  ask: ask,
                  prompt: prompt,
                  startedAt: DateTime.now(),
                ),
              ],
            ),
          );

        case TaskSubagentReasoning(id: final id, text: final chunk):
          _updateSubagent(
            projectId,
            sessionId,
            id,
            (subagent) => subagent.copyWith(
              reasoning: subagent.reasoning + chunk,
              phase: SubagentPhase.thinking,
              clearActivity: true,
            ),
          );

        case TaskSubagentToolUse(
          id: final id,
          name: final name,
          input: final input,
        ):
          final activity = AgentToolActivity.fromToolUse(name, input);
          _updateSubagent(
            projectId,
            sessionId,
            id,
            (subagent) => subagent.copyWith(
              activity: activity,
              phase: SubagentPhase.working,
              tools: [...subagent.tools, activity],
            ),
          );

        case TaskSubagentText(id: final id, text: final chunk):
          _updateSubagent(
            projectId,
            sessionId,
            id,
            (subagent) => subagent.copyWith(
              text: subagent.text + chunk,
              phase: SubagentPhase.writing,
              clearActivity: true,
            ),
          );

        // Lo que devuelve un subagente es su resultado, no un mensaje del
        // hilo: firmarlo como si lo hubiera escrito el padre es justamente lo
        // que hacía que no se pudiera ver quién hizo qué.
        case TaskSubagentFinished(
          id: final id,
          result: final result,
          isError: final isError,
        ):
          _updateSubagent(
            projectId,
            sessionId,
            id,
            (subagent) => subagent.copyWith(
              result: result,
              phase: isError ? SubagentPhase.failed : SubagentPhase.done,
              finishedAt: DateTime.now(),
              clearActivity: true,
            ),
          );

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

        case final TaskTurnCompleted turn:
          turnMeasured = true;
          final isError = turn.isError;
          final costUsd = turn.costUsd;
          final durationMs = turn.durationMs;
          final reportedTokens = TokenUsage(
            inputTokens: turn.inputTokens,
            outputTokens: turn.outputTokens,
            cacheReadTokens: turn.cacheReadTokens,
            cacheCreationTokens: turn.cacheCreationTokens,
          );
          final currentProject = _projectById(projectId);
          final beforeUsage = currentProject == null
              ? const SessionUsage()
              : _sessionById(currentProject, sessionId)?.usage ??
                    const SessionUsage();
          final previousCumulative =
              beforeUsage.cumulativeByProfileId[member.id] ??
              const TokenUsage();
          final turnTokens = turn.tokensReported && turn.usageIsCumulative
              ? reportedTokens.deltaFrom(previousCumulative)
              : reportedTokens;
          final usage = beforeUsage.recordTurn(
            profileId: member.id,
            workNodeId: workNodeId,
            reportedTokens: reportedTokens,
            tokensReported: turn.tokensReported,
            usageIsCumulative: turn.usageIsCumulative,
            reportedCostUsd: costUsd,
            costReported: turn.costReported,
            durationMs: durationMs,
            contextUsedTokens: turn.contextUsedTokens,
            contextWindowTokens: turn.contextWindowTokens,
          );
          _updateSession(
            projectId,
            sessionId,
            (session) => session.copyWith(usage: usage),
          );
          unawaited(
            UsageLedgerService.instance.notifier.record(
              provider: engine.provider.alias,
              model: turn.model.isEmpty ? engine.model : turn.model,
              profileId: member.id,
              projectId: projectId,
              sessionId: sessionId,
              inputTokens: turnTokens.inputTokens,
              outputTokens: turnTokens.outputTokens,
              cacheReadTokens: turnTokens.cacheReadTokens,
              cacheCreationTokens: turnTokens.cacheCreationTokens,
              tokensReported: turn.tokensReported,
              durationMs: durationMs,
              costUsd: costUsd,
              costReported: turn.costReported,
              workNodeId: workNodeId ?? '',
              contextUsedTokens: turn.contextUsedTokens,
              contextWindowTokens: turn.contextWindowTokens,
            ),
          );
          if (isError && turn.hitTurnCap) {
            // No es una falla del agente: el número se quedó corto. Se dice
            // con el número puesto y el motor le pide al nodo cómo quedó
            // (bloque keel-outcome) antes de decidir qué sigue.
            capHit = true;
            _appendMessage(
              projectId,
              sessionId,
              ChatMessage(
                role: ChatRole.system,
                text:
                    'El paso llegó al tope de $maxTurns turnos agénticos. '
                    'Se le pide cómo quedó antes de decidir; si suele '
                    'quedarse corto, subí el tope del paso en el workflow.',
                timestamp: DateTime.now(),
                workNodeId: workNodeId,
              ),
            );
          } else if (isError) {
            turnFailed = true;
            _appendMessage(
              projectId,
              sessionId,
              ChatMessage(
                role: ChatRole.error,
                text: engine.provider.turnFailureMessage(
                  memberName: member.name,
                ),
                timestamp: DateTime.now(),
                workNodeId: workNodeId,
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
            workNodeId: workNodeId,
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
              usage: session.usage.withLatestContext(
                used: usedTokens,
                window: windowTokens,
              ),
            ),
          );

        case TaskNotice(message: final message):
          _appendMessage(
            projectId,
            sessionId,
            ChatMessage(
              role: ChatRole.system,
              text: message,
              timestamp: DateTime.now(),
              workNodeId: workNodeId,
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
              workNodeId: workNodeId,
            ),
          );
      }
    }
    if (livePid != 0) RunningProcesses.unregister(livePid);
    _turnWatchdogs[sessionId]?.remove(watchdog);
    if (_turnWatchdogs[sessionId]?.isEmpty ?? false) {
      _turnWatchdogs.remove(sessionId);
    }
    if (watchdog.tripped && !_stoppedSessionIds.contains(sessionId)) {
      turnFailed = true;
      final minutes = watchdog.trip == TurnWatchdogTrip.idle
          ? watchdog.idle.inMinutes
          : watchdog.hard.inMinutes;
      final reason = watchdog.trip == TurnWatchdogTrip.idle
          ? 'Sin actividad del proveedor durante $minutes min: el paso se '
                'cortó. Si el trabajo legítimamente calla tanto (builds, '
                'suites largas), subí el plazo de inactividad en la policy '
                'del workflow.'
          : 'El paso superó el plazo de $minutes min y se cortó. Partí el '
                'paso en dos o subí el plazo en la policy del workflow.';
      Log.w('Turno cortado por el vigilante: ${watchdog.trip?.name}');
      _appendMessage(
        projectId,
        sessionId,
        ChatMessage(
          role: ChatRole.error,
          text: reason,
          timestamp: DateTime.now(),
          workNodeId: workNodeId,
        ),
      );
    }

    // Un turno parado, caído o con la sesión muerta no llega al evento
    // `result`: sin esta fila, el intento que igual gastó no existe para la
    // app. Importa sobre todo acá, donde el reintento de sesión muerta corre
    // el turno DE NUEVO: el primero se cobraba y era invisible, así que el
    // costo del reintento parecía el costo de un turno solo.
    if (providerEngaged && !turnMeasured) {
      unawaited(
        UsageLedgerService.instance.notifier.record(
          provider: engine.provider.alias,
          model: engine.model,
          profileId: member.id,
          projectId: projectId,
          sessionId: sessionId,
          inputTokens: 0,
          outputTokens: 0,
          cacheReadTokens: 0,
          cacheCreationTokens: 0,
          tokensReported: false,
          durationMs: DateTime.now().difference(turnStartedAt).inMilliseconds,
          costUsd: 0,
          costReported: false,
          workNodeId: workNodeId ?? '',
        ),
      );
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
          session.cliSessionsByExecutionId,
        )..remove(effectiveExecutionId);
        return session.copyWith(cliSessionsByExecutionId: sessions);
      });
      return _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: member,
        workNodeId: workNodeId,
        instruction: instruction,
        consultOfProfileId: consultOfProfileId,
        turnId: turnId,
        depth: depth,
        allowConsults: allowConsults,
        planMode: planMode,
        executionId: effectiveExecutionId,
        maxTurns: maxTurns,
        maxBudgetUsd: maxBudgetUsd,
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
      workNodeId: workNodeId,
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
    _applyDeclaredCoverageBlocks(
      projectId: projectId,
      sessionId: sessionId,
      text: answer.toString(),
    );

    // «Sin texto» ya no es fallo: un turno que trabajó por tools y calló
    // cuenta como turno, y el motor decide con el bloque keel-outcome (o lo
    // pide). `capHit` no cambia `ok` a propósito: lo que quedó lo dice el
    // nodo, no el tope.
    if (capHit) {
      Log.i('Nodo $workNodeId al tope de $maxTurns turnos; se pide el cierre');
    }
    final outcome = (
      ok: !turnFailed,
      answer: answer.toString(),
      report: parseKeelOutcome(answer.toString()),
    );

    if (!turnFailed && allowConsults && depth < _maxConsultDepth) {
      await _resolveConsultations(
        projectId: projectId,
        sessionId: sessionId,
        asker: member,
        workNodeId: workNodeId,
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
    required String? workNodeId,
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
            workNodeId: workNodeId,
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
              workNodeId: workNodeId,
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
          workNodeId: workNodeId,
        ),
      );
    }
    await _persist();
  }

  /// Persists a migration coverage declaration emitted by a resolution owner.
  /// `notApplicable` is intentionally rejected without a rationale so a
  /// migration cannot close by silently skipping a layer.
  void _applyDeclaredCoverageBlocks({
    required String projectId,
    required String sessionId,
    required String text,
  }) {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final resolution = session?.resolutionCase;
    if (resolution == null || resolution.coverage.isEmpty) return;

    var updated = resolution;
    for (final fields in parseFencedBlocks(
      text,
      tag: 'cobertura',
      keys: _coverageBlockKeys,
    )) {
      final area = _coverageAreaFromName(fields['area']);
      final status = _coverageStatusFromName(fields['estado']);
      if (area == null || status == null) continue;
      updated = ResolutionEngine.setCoverage(
        updated,
        area: area,
        status: status,
        rationale: fields['motivo'] ?? '',
      );
    }
    if (updated != resolution) _storeResolution(projectId, sessionId, updated);
  }

  MigrationCoverageArea? _coverageAreaFromName(String? name) {
    for (final area in MigrationCoverageArea.values) {
      if (area.name.toLowerCase() == name?.trim().toLowerCase()) return area;
    }
    return null;
  }

  MigrationCoverageStatus? _coverageStatusFromName(String? name) {
    return switch (name?.trim().toLowerCase()) {
      'satisfied' || 'satisfecho' => MigrationCoverageStatus.satisfied,
      'notapplicable' ||
      'not_applicable' ||
      'no_aplica' => MigrationCoverageStatus.notApplicable,
      _ => null,
    };
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
    required String? workNodeId,
    required String text,
    required String turnId,
    required int depth,
  }) async {
    final project = _projectById(projectId);
    if (project == null) return;

    final open = _sessionById(project, sessionId);
    final members = membersOf(project, session: open);
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

      final consulta = await _runTurn(
        projectId: projectId,
        sessionId: sessionId,
        member: target,
        workNodeId: workNodeId,
        instruction: consultRequestPrompt(
          askerHandle: asker.name,
          askerRole: asker.role,
          excerpt: _consultExcerpt(text, handle),
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
        workNodeId: workNodeId,
        instruction: consultAnswerPrompt(
          targetHandle: target.name,
          answer: consulta.answer,
        ),
        consultOfProfileId: null,
        turnId: turnId,
        depth: depth + 1,
        allowConsults: false,
      );
    }
  }

  // ── prompts ─────────────────────────────────────────────────────────

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

  /// Composes what this member knows for the whole turn: the global skills
  /// every agent carries, who it is, the project's shared rules and
  /// documents, and who else it can consult.
  ///
  /// El orden es contrato: skills globales → prompt del perfil → skills →
  /// reglas → IDENTIDAD → solo lectura → COMPAÑEROS → GITHUB POR MCP → MODO
  /// DE TRABAJO → ENTREGA → REGLA DE SUBAGENTES → saber → plan. Las dos
  /// últimas secciones cambian durante un workflow y quedan al final para
  /// conservar el prefijo estable del prompt.
  ///
  /// El texto de cada sección vive en `integrations/system_prompt/`. Acá se
  /// decide el ORDEN y qué secciones entran, que es lo que depende del
  /// estado de la app.
  String _turnSystemPrompt(
    Project project,
    AgentProfile member, {
    Session? session,
    required bool isConsult,
    required bool hasPlanTools,
    required bool usesGit,
    required WorktreePlace place,
    bool usesGithubMcp = false,

    /// Solo lo que no se puede perder: identidad, reglas y contratos. Es lo
    /// que codex recibe en cada turno reanudado, donde repetir las skills y
    /// el saber costaría lo mismo que el turno 1 cada vez.
    bool compact = false,
  }) {
    final sections = <PromptSection>[];

    final skills = SkillsService.instance.notifier.data.skills;
    var globalCount = 0;
    for (final skill in skills) {
      if (!skill.isGlobal || skill.content.isEmpty) continue;
      globalCount++;
      // Las dos primeras globales se quedan siempre; las de más salen antes
      // que las reglas y después que el saber si el prompt no entra.
      sections.add(
        PromptSection(
          name: 'skill global ${skill.name}',
          text: skill.content,
          dropPriority: globalCount <= 2 ? 0 : 1,
        ),
      );
    }

    if (member.systemPrompt.isNotEmpty) {
      sections.add(
        PromptSection(name: 'perfil de @${member.name}', text: member.systemPrompt),
      );
    }

    final workflowForTurn = session == null ? null : workflowOf(session);
    final requiredPolicy = workflowForTurn?.policy;
    final requiredSkillNames = {...?requiredPolicy?.requiredSkillNames};
    final skillNames = {
      ...member.skills,
      ...?workflowForTurn?.skillNames,
      ...requiredSkillNames,
    };
    final assignedSkills = assignedNonGlobalSkills(skills, skillNames);
    for (final name in skillNames) {
      final skill = skills.where((s) => s.name == name).firstOrNull;
      if (skill == null || skill.content.isEmpty) {
        Log.w('Skill "$name" referenced by ${member.name} not found or empty');
      }
    }
    for (final skill in assignedSkills) {
      sections.add(
        PromptSection(
          name: 'skill ${skill.name}',
          text: skill.content,
          // Una skill que la policy del workflow EXIGE no se recorta.
          dropPriority: requiredSkillNames.contains(skill.name) ? 0 : 2,
        ),
      );
    }

    final rules = RulesService.instance.notifier.data.rules;
    final ruleNames = {
      ...member.rules,
      ...project.ruleNames,
      ...?requiredPolicy?.requiredRuleNames,
    };
    for (final name in ruleNames) {
      final rule = rules.where((r) => r.name == name).firstOrNull;
      if (rule == null || rule.content.isEmpty) {
        Log.w(
          'Rule "$name" referenced by project "${project.name}" not found or empty',
        );
        continue;
      }
      sections.add(PromptSection(name: 'regla $name', text: rule.content));
    }

    final companions = membersOf(
      project,
      session: session,
    ).where((m) => m.id != member.id).toList();

    final contracts = StringBuffer();
    // IDENTIDAD — siempre, haya compañeros o no. Cuando estaba adentro del
    // `if` de compañeros, un proyecto de un solo miembro perdía entero el
    // "SOS @handle" y el nombre del proyecto.
    contracts.writeln(
      identityPrompt(
        handle: member.name,
        role: member.role,
        projectName: project.name,
        projectPurpose: project.purpose,
      ),
    );
    if (!project.maintained) {
      contracts.writeln();
      contracts.writeln(kReadOnlyProjectPrompt);
    }
    if (companions.isNotEmpty) {
      contracts.writeln(
        companionsPrompt([
          for (final companion in companions)
            (handle: companion.name, role: companion.role),
        ]),
      );
    }
    if (usesGithubMcp) {
      contracts.writeln();
      contracts.writeln(kGithubMcpPrompt);
    }
    contracts.writeln();
    contracts.writeln(kAskVsWorkPrompt);
    // Solo en el turno de un NODO: una consulta o un chat sin workflow no
    // tienen motor esperando el bloque.
    if (!isConsult && session?.resolutionCase != null) {
      contracts.writeln();
      contracts.writeln(kOutcomeProtocolPrompt);
    }
    // La entrega es del que trabaja, no del que responde una consulta; y
    // solo tiene sentido donde hay git.
    if (!isConsult && usesGit) {
      contracts.writeln();
      // Con el MCP de GitHub asignado, la variante que abre el PR por tool:
      // dejar la de `gh` sería contradecir a kGithubMcpPrompt, que ya entró
      // más arriba en este mismo prompt.
      contracts.writeln(usesGithubMcp ? kGithubDeliveryPrompt : kDeliveryPrompt);
      final worktree = worktreePrompt(place);
      if (worktree.isNotEmpty) {
        contracts.writeln();
        contracts.writeln(worktree);
      }
    }
    contracts.writeln();
    contracts.writeln(
      subagentPolicyPrompt(
        provider: project.tuned(member).provider,
        maxSubagents: requiredPolicy?.maxSubagents ?? 0,
      ),
    );
    sections.add(PromptSection(name: 'contratos', text: contracts.toString()));

    final saber = KnowledgeService.instance.notifier.briefFor(
      <String>{
        ...project.knowledgeBaseNames,
        ...member.knowledgeBaseNames,
        ...?requiredPolicy?.requiredKnowledgeBaseNames,
      }.toList(),
    );
    const saberName = 'saber';
    if (saber.trim().isNotEmpty) {
      sections.add(PromptSection(name: saberName, text: saber, dropPriority: 3));
    }

    final candidates = compact
        ? [for (final section in sections) if (section.dropPriority == 0) section]
        : sections;
    final budgeted = budgetTurnSystemPrompt(
      candidates,
      maxChars: requiredPolicy?.systemPromptMaxChars ?? kDefaultSystemPromptMaxChars,
    );
    if (budgeted.dropped.isNotEmpty) {
      Log.w(
        'System prompt de @${member.name} recortado: ${budgeted.totalChars} '
        'chars, fuera ${budgeted.dropped.join(', ')}',
      );
    }
    final keptSaber = !budgeted.dropped.contains(saberName) &&
        candidates.any((section) => section.name == saberName);
    // Lo que sobrevivió al presupuesto, en el mismo orden; el saber y el
    // plan al final para no romper el prefijo cacheable.
    final stableKept = [
      for (final section in candidates)
        if (section.name != saberName &&
            !budgeted.dropped.contains(section.name))
          section.text.trim(),
    ].where((text) => text.isNotEmpty).join('\n\n');

    final plan = planSectionPrompt(
      session,
      isConsult: isConsult,
      hasPlanTools: hasPlanTools,
    );
    return composeTurnSystemPrompt(
      stablePrompt: stableKept,
      knowledge: keptSaber ? saber : '',
      plan: plan,
    );
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

  /// El workflow POR DEFECTO del proyecto: con cuál abre una sesión nueva si
  /// nadie elige otro. No es con el que corre cada sesión — eso lo dice la
  /// sesión, que es donde el dato pertenece.
  Workflow? defaultWorkflowOf(Project project) =>
      _workflowById(project.activeWorkflowId);

  /// Con qué corre ESTA sesión. Null mientras no eligió ninguno.
  Workflow? workflowOf(Session session) => _workflowById(session.workflowId);

  /// El de la sesión [sessionId] de [project], si esa sesión sigue existiendo.
  Workflow? _workflowRunning(Project project, String sessionId) {
    final session = _sessionById(project, sessionId);
    return session == null ? null : workflowOf(session);
  }

  static Workflow? _workflowById(String? id) {
    if (id == null || id.isEmpty) return null;
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    return workflows.where((workflow) => workflow.id == id).firstOrNull;
  }

  /// Los workflows que este proyecto puede elegir, en el orden en que se
  /// atarron. El de formato entra siempre: es de la app, no del proyecto, y
  /// obligar a engancharlo sería obligar a configurar lo único que un
  /// proyecto recién creado necesita sí o sí.
  List<Workflow> choosableWorkflowsOf(Project project) {
    final all = WorkflowsService.instance.notifier.data.workflows;
    final chosen = [
      for (final id in project.workflowIds)
        ...all.where((workflow) => workflow.id == id),
    ];
    final formato = all
        .where((workflow) => workflow.name == kRoadmapFormatWorkflowName)
        .firstOrNull;
    if (formato != null && !chosen.any((flow) => flow.id == formato.id)) {
      chosen.add(formato);
    }
    return chosen;
  }

  /// Cambia el workflow de una sesión. **Solo antes de que arranque**: con
  /// pasos corridos, la mitad del hilo salió de otra fila de agentes y el
  /// `3/7` pasaría a contar sobre una escala que nunca se usó.
  bool setSessionWorkflow(String projectId, String sessionId, String id) {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    if (session == null || session.messages.isNotEmpty) return false;
    _updateSession(
      projectId,
      sessionId,
      (open) => open.copyWith(workflowId: id),
    );
    unawaited(_persist());
    return true;
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

  /// Associates a message with the persisted graph node that owns this turn.
  /// Node identity survives a localized reformulation; an array position does
  /// not and therefore must never be persisted as workflow state.
  String? _activeWorkNodeId(Session session) => session.resolutionCase?.nodes
      .where((node) => node.status == WorkNodeStatus.running)
      .firstOrNull
      ?.id;

  int nodeCountFor(Project project) {
    final workflow = defaultWorkflowOf(project);
    if (workflow == null) return 0;
    return ResolutionEngine.start(
      id: 'preview',
      kind: workflow.kind,
      ownerRole: workflow.policy.resolutionRole,
      capabilities: workflow.capabilities,
    ).nodes.length;
  }

  int nodeCountOf(Session session) => session.resolutionCase?.nodes.length ?? 0;

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

    final sealed = status == SessionStatus.finished
        ? _formatCheckVerdict(projectId, sessionId)
        : status;

    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(
        status: sealed,
        isRunning: false,
        clearLiveTurn: true,
      ),
    );
  }

  /// El chequeo obligatorio de la sesión que arma el formato.
  ///
  /// Va acá, en el ÚNICO lugar por donde pasan todos los cierres, y no en el
  /// camino feliz: una verificación que se puede esquivar por otra rama no es
  /// una verificación. Pedirle al agente que verifique su propio trabajo por
  /// prompt sería pedir; esto no pide.
  ///
  /// El resultado se publica en el hilo con la lista entera —lo que pasó y lo
  /// que no— porque la sesión sigue abierta y lo que falla es el pedido
  /// siguiente.
  SessionStatus _formatCheckVerdict(String projectId, String sessionId) {
    final project = _projectById(projectId);
    final session = project == null ? null : _sessionById(project, sessionId);
    final buildsRoadmap = session == null
        ? false
        : (workflowOf(session)?.buildsRoadmap ?? false);
    if (project == null || session == null || !buildsRoadmap) {
      return SessionStatus.finished;
    }

    final check = checkRoadmapFormat(project.workingDirectory);
    // Idempotente y barato: acá está el único punto por el que pasan también
    // las carpetas que ya existían antes de que Keel las ignorara.
    if (check.ok) unawaited(ensureRoadmapIgnored(project.workingDirectory));
    final lineas = [
      for (final done in check.passed) '  ✓  $done',
      for (final finding in check.findings) '  ✗  $finding',
    ].join('\n');

    _appendMessage(
      projectId,
      sessionId,
      ChatMessage(
        role: check.ok ? ChatRole.system : ChatRole.error,
        text: check.ok
            ? 'Chequeo del formato — ${check.passed.length} de ${check.total}\n'
                  '$lineas\n'
                  'El formato cierra. El estado del proyecto ya lo está leyendo.'
            : 'Chequeo del formato — ${check.passed.length} de ${check.total}\n'
                  '$lineas\n'
                  'La sesión sigue abierta: arreglá eso y volvé a cerrar.',
        timestamp: DateTime.now(),
      ),
    );

    return check.ok ? SessionStatus.finished : SessionStatus.failed;
  }

  void _appendMessage(String projectId, String sessionId, ChatMessage message) {
    _updateSession(
      projectId,
      sessionId,
      (session) => session.copyWith(messages: [...session.messages, message]),
    );
  }

  void _appendStreamingAssistantMessage(
    String projectId,
    String sessionId,
    ChatMessage chunk,
  ) {
    _updateSession(projectId, sessionId, (session) {
      final messages = [...session.messages];
      final index = messages.lastIndexWhere(
        (message) =>
            message.role == ChatRole.assistant &&
            message.timestamp == chunk.timestamp,
      );
      if (index == -1) {
        messages.add(chunk);
      } else {
        // Append, nunca reemplazar: el colector se vacía en cada lectura, así
        // que el chunk siguiente a una edición trae la lista vacía y borraba
        // la tarjeta del diff. Mismo defecto que el chat 1:1.
        messages[index] = messages[index].appendingChunk(
          text: chunk.text,
          fileEdits: chunk.fileEdits,
          reasoning: chunk.reasoning,
        );
      }
      return session.copyWith(messages: messages);
    });
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
        // `copyWith`, no reconstruir: rearmarlo desde `text` + `fileEdits`
        // aplanaba la secuencia de bloques justo al cerrar el turno.
        messages[i] = messages[i].copyWith(
          costUsd: costUsd,
          durationMs: durationMs,
        );
        break;
      }
      return session.copyWith(messages: messages);
    });
  }

  /// Narrows [_updateSession] to the turn in flight, so a chunk that arrives
  /// after the turn ended is dropped instead of resurrecting a dead strip.
  /// Un subagente que ya arrancó. Si el id no está, no hace nada: un evento
  /// de un `Task` que nunca vimos abrir es de otro turno, no un subagente
  /// nuevo sin pedido.
  void _updateSubagent(
    String projectId,
    String sessionId,
    String id,
    SessionSubagent Function(SessionSubagent subagent) update,
  ) {
    _updateSession(projectId, sessionId, (session) {
      if (session.subagents.every((entry) => entry.id != id)) return session;
      return session.copyWith(
        subagents: [
          for (final entry in session.subagents)
            if (entry.id == id) update(entry) else entry,
        ],
      );
    });
  }

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
    AgentProfile member, {
    DecisionGateSpec? gate,
  }) async {
    await HooksService.instance.notifier.ready;
    final catalog = HooksService.instance.notifier.data.hooks;
    if (catalog.isEmpty && gate == null) return TurnHooks.none;

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
      gate: gate,
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

  /// Removes a deleted workflow from all persisted project configuration.
  /// Sessions keep their messages and materialized resolution graph, but no
  /// longer retain an ID that cannot resolve against the workflow catalog.
  int detachWorkflow(String workflowId) {
    final affected = data.projects
        .where((project) => project.referencesWorkflow(workflowId))
        .length;
    if (affected == 0) return 0;

    final projects = [
      for (final project in data.projects)
        if (project.referencesWorkflow(workflowId))
          project.withoutWorkflow(workflowId)
        else
          project,
    ];
    updateState(data.copyWith(projects: projects));
    unawaited(_repository.save(projects));
    return affected;
  }

  Future<void> _persist() => _repository.save(data.projects);
}

mixin ProjectsService {
  static final ReactiveNotifier<ProjectsViewModel> instance =
      ReactiveNotifier<ProjectsViewModel>(() => ProjectsViewModel());
}
