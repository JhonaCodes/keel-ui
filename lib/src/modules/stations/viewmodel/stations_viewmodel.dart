import 'dart:async';
import 'dart:convert';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';
import 'package:keel_ui/src/integrations/task_plan_mcp/task_plan_mcp_server.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
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
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
import 'package:keel_ui/src/modules/stations/model/task_live_turn.dart';
import 'package:keel_ui/src/modules/stations/model/task_plan_item.dart';
import 'package:keel_ui/src/modules/stations/repository/stations_repository.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Matches an `@handle` mention of a station member. Same shape the profile
/// name validator enforces, so a mention can only ever name a real handle.
final RegExp _mentionPattern = RegExp(r'@([a-z0-9_-]{1,16})');

/// The fields a `\`\`\`agente` declaration block recognizes. Parsed by the
/// shared [parseFencedBlocks] — kept deliberately rigid so reading it is a
/// decision, not a guess about prose.
const _agentDeclarationKeys = {'handle', 'rol', 'proposito', 'instrucciones'};

/// El plan de la tarea es lo que el usuario mira para saber qué falta. Un
/// plan que solo vive como mensaje del hilo deja de ser consultable a los
/// diez turnos: por eso hay tools, y por eso el turno las nombra.
const _planPrompt =
    'PLAN DE LA TAREA: esta tarea tiene un plan visible para el usuario, con '
    'sus puntos y cuáles están cumplidos.\n'
    '- Si tu paso es planificar, escribilo con `set_task_plan`: puntos '
    'concretos y verificables, no las etapas del workflow (esas ya se ven '
    'aparte). Si el plan cambia a mitad de camino, volvé a llamarla — lo que '
    'ya estaba hecho y sigue igual se conserva marcado.\n'
    '- Al cerrar tu turno, marcá con `complete_plan_items` los puntos que '
    'efectivamente resolviste, con su texto exacto. Solo esos: el usuario lee '
    'esto para saber qué queda, y marcar de más lo deja ciego.\n'
    '- Si no hay plan todavía y tu paso no es planificar, no lo inventes.';

/// Nothing an agent does may be invisible. The CLI can spawn subagents of its
/// own, which run outside the channel, cost money, and answer to nobody the
/// user registered — so they are forbidden outright, and the way to get a
/// specialist is to declare it and have the app register it in the open.
/// El título con el que nace una tarea. Vale como marca de "todavía no
/// tiene nombre propio": mientras siga siendo este, el primer pedido la
/// renombra sola.
const kDefaultTaskTitle = 'Tarea nueva';

const _noBackgroundWorkPrompt =
    'REGLA DEL CANAL, POR ENCIMA DE CUALQUIER OTRA COSA: no lanzás trabajo '
    'en segundo plano. Nada de subagentes propios, nada de delegar a procesos '
    'que el usuario no ve. Todo lo que pase tiene que pasar en este hilo, a '
    'la vista.\n'
    'Si te falta un especialista que la estación no tiene, NO lo inventes ni '
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

class StationsViewModel extends ViewModel<StationsState> {
  StationsViewModel() : super(const StationsState());

  StationsRepository get _repository => StationsRepository();

  /// Keyed by **task**, not by station: a station can have several tasks in
  /// flight at once, each owning its own runner. Within one task the turns
  /// still run strictly in sequence, so the agents of a single task never
  /// write files on top of each other.
  final Map<String, TaskRun> _runningTasks = {};
  final Set<String> _stoppedTaskIds = {};

  /// Who was blocked when a task asked you for a permission, so granting it
  /// resumes that member and not whoever happened to speak last.
  final Map<String, String> _permissionBlockedProfileByTask = {};

  /// `turn:asker>target` pairs already consulted. Scoped to a single turn on
  /// purpose: it stops two agents rebounding inside one answer, while a new
  /// question from the user opens a fresh turn where they may consult each
  /// other again. Keying it per step instead blocked every later consult for
  /// the rest of that step.
  final Set<String> _consultedPairs = {};

  static const _maxConsultDepth = 3;

  /// The consult ledger is keyed by turnId, which never repeats — without a
  /// purge it grows for the app's whole lifetime. Cleared whenever no task
  /// is running: no in-flight turn can still need its pairs then.
  void _purgeConsultLedgerIfIdle() {
    if (_runningTasks.isEmpty) _consultedPairs.clear();
  }

  /// Resolves once the persisted stations have loaded — same guarded-ready
  /// pattern as the other catalogs, so the catalog sync (and any MCP-driven
  /// first access) can await real data, and a later
  /// `reinitializeWithContext()` never wipes loaded state.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedStations();

  @override
  void init() {
    if (_ready == null) updateSilently(const StationsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedStations() async {
    try {
      final stations = await _repository.load();
      updateState(data.copyWith(stations: _revived(stations)));
    } catch (error) {
      Log.e('Failed to load persisted stations', error: error);
    }
  }

  /// No CLI process survives closing the app, so a task that comes back from
  /// disk saying it is running is lying — it was interrupted mid-turn. Left
  /// alone the flag never clears: the composer stays disabled, the progress
  /// bar spins forever, and `sendToChannel` returns early on every message.
  /// The channel looks hung because, as far as the state is concerned, it is.
  List<Station> _revived(List<Station> stations) {
    return [
      for (final station in stations)
        station.copyWith(
          tasks: [
            for (final task in station.tasks)
              task.isRunning ? task.copyWith(isRunning: false) : task,
          ],
        ),
    ];
  }

  // ── alta y configuración ────────────────────────────────────────────

  /// Registers a station. Returns a user-facing error message on failure
  /// (invalid or duplicate name), or null on success.
  String? createStation({
    required String name,
    required String purpose,
    required String workingDirectory,
    required List<String> profileIds,
    required List<String> workflowIds,
    required List<String> ruleNames,
    required List<String> knowledgeBaseNames,
  }) {
    final error = _validateName(name);
    if (error != null) return error;

    final station = Station(
      id: generateUuidV4(),
      name: name,
      purpose: purpose.trim(),
      workingDirectory: workingDirectory.trim(),
      profileIds: profileIds,
      workflowIds: workflowIds,
      ruleNames: ruleNames,
      knowledgeBaseNames: knowledgeBaseNames,
      activeWorkflowId: workflowIds.isEmpty ? null : workflowIds.first,
      createdAt: DateTime.now(),
    );
    final stations = [...data.stations, station];
    updateState(
      data.copyWith(stations: stations, selectedStationId: station.id),
    );
    unawaited(_repository.save(stations));
    return null;
  }

  /// Updates a station's configuration. Its tasks are untouched — the station
  /// is the durable part. Returns a user-facing error message, or null.
  String? updateStation(
    String id, {
    required String name,
    required String purpose,
    required String workingDirectory,
    required List<String> profileIds,
    required List<String> workflowIds,
    required List<String> ruleNames,
    required List<String> knowledgeBaseNames,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final stations = data.stations.map((station) {
      if (station.id != id) return station;
      final keepsActive =
          station.activeWorkflowId != null &&
          workflowIds.contains(station.activeWorkflowId);
      return station.copyWith(
        name: name,
        purpose: purpose.trim(),
        workingDirectory: workingDirectory.trim(),
        profileIds: profileIds,
        workflowIds: workflowIds,
        ruleNames: ruleNames,
        knowledgeBaseNames: knowledgeBaseNames,
        activeWorkflowId: keepsActive
            ? station.activeWorkflowId
            : (workflowIds.isEmpty ? null : workflowIds.first),
        clearActiveWorkflow: !keepsActive && workflowIds.isEmpty,
      );
    }).toList();

    updateState(data.copyWith(stations: stations));
    unawaited(_repository.save(stations));
    return null;
  }

  void deleteStation(String id) {
    for (final task in _stationById(id)?.tasks ?? const <StationTask>[]) {
      _runningTasks.remove(task.id)?.cancel();
      _stoppedTaskIds.remove(task.id);
    }
    final stations = data.stations.where((s) => s.id != id).toList();
    final clearing = data.selectedStationId == id;
    updateState(
      StationsState(
        stations: stations,
        selectedStationId: clearing ? null : data.selectedStationId,
      ),
    );
    unawaited(_repository.save(stations));
  }

  void selectStation(String id) {
    updateState(data.copyWith(selectedStationId: id));
  }

  /// Adds a rule to the station without leaving the channel — the panel is
  /// where you notice a rule is missing, so it is also where you add it.
  void addRule(String stationId, String ruleName) {
    _updateStation(stationId, (station) {
      if (station.ruleNames.contains(ruleName)) return station;
      return station.copyWith(ruleNames: [...station.ruleNames, ruleName]);
    });
    unawaited(_persist());
  }

  void removeRule(String stationId, String ruleName) {
    _updateStation(
      stationId,
      (station) => station.copyWith(
        ruleNames: station.ruleNames.where((r) => r != ruleName).toList(),
      ),
    );
    unawaited(_persist());
  }

  void addKnowledgeBase(String stationId, String baseName) {
    _updateStation(stationId, (station) {
      if (station.knowledgeBaseNames.contains(baseName)) return station;
      return station.copyWith(
        knowledgeBaseNames: [...station.knowledgeBaseNames, baseName],
      );
    });
    unawaited(_persist());
  }

  void removeKnowledgeBase(String stationId, String baseName) {
    _updateStation(
      stationId,
      (station) => station.copyWith(
        knowledgeBaseNames: station.knowledgeBaseNames
            .where((name) => name != baseName)
            .toList(),
      ),
    );
    unawaited(_persist());
  }

  // ── plan de trabajo de una tarea ────────────────────────────────────

  /// Fija el plan de la tarea. Reemplaza el anterior, pero **conserva el
  /// estado de los puntos cuyo texto no cambió**: replanificar a mitad de
  /// camino no puede desmarcar lo que ya se hizo.
  void setTaskPlan(String stationId, String taskId, List<String> items) {
    _updateTask(stationId, taskId, (task) {
      final anteriores = {
        for (final item in task.plan) item.text.trim(): item,
      };
      return task.copyWith(
        plan: [
          for (final text in items)
            if (text.trim().isNotEmpty)
              anteriores[text.trim()] ??
                  TaskPlanItem(id: generateUuidV4(), text: text.trim()),
        ],
      );
    });
    unawaited(_persist());
  }

  /// Marca puntos del plan como hechos. Acepta el id o el texto exacto: el
  /// modelo tiene los dos a la vista y exigir el id convierte un acierto en
  /// un fallo silencioso. Devuelve los que no encontró.
  List<String> completePlanItems(
    String stationId,
    String taskId, {
    required List<String> items,
    String? byProfileId,
  }) {
    final station = _stationById(stationId);
    final task = station == null ? null : _taskById(station, taskId);
    if (task == null) return items;

    final buscados = items.map((entry) => entry.trim()).toSet();
    final encontrados = <String>{};
    final plan = [
      for (final item in task.plan)
        if (buscados.contains(item.id) || buscados.contains(item.text.trim()))
          () {
            encontrados.add(
              buscados.contains(item.id) ? item.id : item.text.trim(),
            );
            return item.copyWith(done: true, doneByProfileId: byProfileId);
          }()
        else
          item,
    ];

    _updateTask(stationId, taskId, (current) => current.copyWith(plan: plan));
    unawaited(_persist());
    return buscados.difference(encontrados).toList();
  }

  /// El plan de una tarea, o vacío si no existe. Para quien lo lee de
  /// afuera del árbol de widgets (el servidor MCP del plan).
  List<TaskPlanItem> planOf(String stationId, String taskId) {
    final station = _stationById(stationId);
    if (station == null) return const [];
    return _taskById(station, taskId)?.plan ?? const [];
  }

  /// Des/marca un punto a mano — el veredicto final es del usuario.
  void togglePlanItem(String stationId, String taskId, String itemId) {
    _updateTask(stationId, taskId, (task) {
      return task.copyWith(
        plan: [
          for (final item in task.plan)
            if (item.id == itemId)
              item.copyWith(done: !item.done, clearDoneBy: item.done)
            else
              item,
        ],
      );
    });
    unawaited(_persist());
  }

  void removePlanItem(String stationId, String taskId, String itemId) {
    _updateTask(stationId, taskId, (task) {
      return task.copyWith(
        plan: task.plan.where((item) => item.id != itemId).toList(),
      );
    });
    unawaited(_persist());
  }

  /// Renombra una tarea a mano. Un título vacío la devuelve al de fábrica,
  /// que es lo que deja que el primer pedido vuelva a nombrarla sola.
  void renameTask(String stationId, String taskId, String title) {
    final limpio = title.trim();
    _updateTask(
      stationId,
      taskId,
      (task) => task.copyWith(
        title: limpio.isEmpty ? kDefaultTaskTitle : limpio,
      ),
    );
    unawaited(_persist());
  }

  void setActiveWorkflow(String stationId, String workflowId) {
    _updateStation(
      stationId,
      (station) => station.copyWith(activeWorkflowId: workflowId),
    );
    unawaited(_persist());
  }

  String? _validateName(String name, {String? excludingId}) {
    final formatError = validateStationName(name);
    if (formatError != null) return formatError;

    final isTaken = data.stations.any(
      (station) => station.name == name && station.id != excludingId,
    );
    if (isTaken) return 'Ya existe una estación con ese nombre.';
    return null;
  }

  // ── tareas ──────────────────────────────────────────────────────────

  void selectTask(String stationId, String taskId) {
    _updateStation(
      stationId,
      (station) => station.copyWith(activeTaskId: taskId),
    );
    unawaited(_persist());
  }

  /// Opens an empty task and selects it. **This is the only way a task is
  /// created** — writing in the channel never spawns one, so a follow-up
  /// question inside a task stays inside that task. Each task is its own
  /// environment: its own thread, its own CLI sessions, independent of the
  /// other tasks in the same station.
  void createTask(String stationId) {
    final task = StationTask(
      id: generateUuidV4(),
      title: kDefaultTaskTitle,
      createdAt: DateTime.now(),
    );
    _updateStation(
      stationId,
      (station) => station.copyWith(
        tasks: [...station.tasks, task],
        activeTaskId: task.id,
      ),
    );
    unawaited(_persist());
  }

  /// Drops a task and everything it accumulated: its thread and its CLI
  /// sessions. The station keeps its members, workflows, rules and documents.
  void closeTask(String stationId, String taskId) {
    _runningTasks.remove(taskId)?.cancel();
    _stoppedTaskIds.add(taskId);

    _updateStation(stationId, (station) {
      final tasks = station.tasks.where((task) => task.id != taskId).toList();
      final wasActive = station.activeTaskId == taskId;
      return station.copyWith(
        tasks: tasks,
        activeTaskId: wasActive ? null : station.activeTaskId,
        clearActiveTask: wasActive,
      );
    });
    unawaited(_persist());
  }

  void stopTask(String stationId, String taskId) {
    final run = _runningTasks.remove(taskId);
    if (run == null) return;

    _stoppedTaskIds.add(taskId);
    run.cancel();

    _appendMessage(
      stationId,
      taskId,
      ChatMessage(
        role: ChatRole.error,
        text: 'Detenido por el usuario.',
        timestamp: DateTime.now(),
      ),
    );
    _finishTask(stationId, taskId, StationTaskStatus.failed);
  }

  /// Runs the station's active workflow inside [taskId], from its first step
  /// to its last. Every member starts from a brand new CLI session, so a task
  /// never inherits context from another one.
  ///
  /// Several tasks can be in flight in the same station: each owns its own
  /// runner and its own sessions, so running one never interrupts another.
  Future<void> _runWorkflow(
    String stationId,
    String taskId,
    String request,
  ) async {
    final station = _stationById(stationId);
    if (station == null) return;

    // El título se deduce del primer pedido SOLO si sigue siendo el de
    // fábrica: si el usuario ya lo puso a mano, el suyo manda.
    _updateTask(
      stationId,
      taskId,
      (task) => task.title == kDefaultTaskTitle
          ? task.copyWith(title: _titleFor(request))
          : task,
    );
    _appendMessage(
      stationId,
      taskId,
      ChatMessage(
        role: ChatRole.user,
        text: request,
        timestamp: DateTime.now(),
      ),
    );

    final workflow = activeWorkflowOf(station);
    if (workflow == null) {
      _appendMessage(
        stationId,
        taskId,
        ChatMessage(
          role: ChatRole.error,
          text:
              'Esta estación no tiene un workflow activo. Agregá uno para que '
              'sepa cómo repartir el trabajo.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    if (workflow.steps.isEmpty) {
      _appendMessage(
        stationId,
        taskId,
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
    _stoppedTaskIds.remove(taskId);
    _updateTask(stationId, taskId, (task) => task.copyWith(isRunning: true));
    await _persist();

    final bool ended;
    try {
      ended = await _runSteps(stationId, taskId, workflow, trimmed);
    } catch (error) {
      return _abandonRun(stationId, taskId, error);
    }

    _runningTasks.remove(taskId);
    final stopped = _stoppedTaskIds.remove(taskId);
    if (!stopped && !ended) {
      _finishTask(stationId, taskId, StationTaskStatus.finished);
    }
    await _persist();
  }

  /// Walks the workflow's steps in order, one turn each. Returns true when it
  /// already closed the task itself — a step naming a role no member holds
  /// ends the run as failed, and the caller must not stamp "finished" on top.
  Future<bool> _runSteps(
    String stationId,
    String taskId,
    Workflow workflow,
    String trimmed,
  ) async {
    for (var index = 0; index < workflow.steps.length; index++) {
      if (_stoppedTaskIds.contains(taskId)) break;

      final step = workflow.steps[index];
      final current = _stationById(stationId);
      if (current == null) break;

      final member = _memberForRole(
        current,
        step.role,
        task: _taskById(current, taskId),
      );
      if (member == null) {
        _appendMessage(
          stationId,
          taskId,
          ChatMessage(
            role: ChatRole.error,
            text:
                'Ningún agente de esta estación tiene el rol "${step.role}", '
                'que pide el paso "${step.title}". El flujo se detiene acá.',
            timestamp: DateTime.now(),
            stepIndex: index,
          ),
        );
        _finishTask(stationId, taskId, StationTaskStatus.failed);
        await _persist();
        return true;
      }

      _updateTask(
        stationId,
        taskId,
        (task) => task.copyWith(currentStepIndex: index),
      );

      await _runTurn(
        stationId: stationId,
        taskId: taskId,
        member: member,
        stepIndex: index,
        instruction: _stepPrompt(step, index, workflow, trimmed),
        consultOfProfileId: null,
        turnId: generateUuidV4(),
        depth: 0,
      );
    }
    return false;
  }

  /// A step that blows up must still end the run. Without this the loop
  /// escapes with `isRunning` left on and the channel is locked for good.
  Future<void> _abandonRun(
    String stationId,
    String taskId,
    Object error,
  ) async {
    Log.e('Workflow run failed', error: error);
    _runningTasks.remove(taskId);
    _stoppedTaskIds.remove(taskId);
    _appendMessage(
      stationId,
      taskId,
      ChatMessage(
        role: ChatRole.error,
        text: 'El flujo se cortó por un error inesperado: $error',
        timestamp: DateTime.now(),
      ),
    );
    _finishTask(stationId, taskId, StationTaskStatus.failed);
    await _persist();
  }

  /// What the composer calls. Everything it does happens **inside the task
  /// that is already open** — it never creates one. The first message of a
  /// task kicks off the workflow; every message after that is a follow-up to
  /// the agent that is holding the work.
  Future<void> sendToChannel(String stationId, String text) async {
    final trimmedForInsights = text.trim();
    if (trimmedForInsights.isNotEmpty) {
      // Zero-token recurrence detector — never in the send critical path.
      unawaited(
        PromptInsightsService.instance.notifier.record(trimmedForInsights),
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final station = _stationById(stationId);
    if (station == null) return;

    final task = station.activeTask;
    if (task == null) return;
    if (task.isRunning) return;

    final started = task.messages.any(
      (message) => message.role == ChatRole.assistant,
    );
    if (!started) return _runWorkflow(stationId, task.id, trimmed);

    final member = _followUpOwner(station, task);
    if (member == null) {
      _appendMessage(
        stationId,
        task.id,
        ChatMessage(
          role: ChatRole.error,
          text:
              'Ningún agente de esta estación puede tomar este mensaje. '
              'Revisá que los roles del workflow tengan agentes asignados.',
          timestamp: DateTime.now(),
        ),
      );
      await _persist();
      return;
    }

    _appendMessage(
      stationId,
      task.id,
      ChatMessage(
        role: ChatRole.user,
        text: trimmed,
        timestamp: DateTime.now(),
      ),
    );
    await _runMemberTurn(
      stationId: stationId,
      taskId: task.id,
      member: member,
      stepIndex: task.currentStepIndex,
      instruction: trimmed,
    );
  }

  /// A member hit a tool it is not allowed to use. The CLI runs headless, so
  /// it cannot stop and ask — it just denies and keeps going, often several
  /// times in the same turn. So the task asks *once*, on your behalf, and
  /// remembers who was blocked in order to resume them if you say yes.
  void _handlePermissionDenied({
    required String stationId,
    required String taskId,
    required AgentProfile member,
    required int stepIndex,
    required PermissionRequest request,
  }) {
    final station = _stationById(stationId);
    if (station == null) return;

    // The sandbox is the station's working directory, which is a setting of
    // the station, not something to grant per turn. Say so plainly instead of
    // offering a button that would not fix it.
    if (request.isSandboxRestriction) {
      final alreadySaid =
          _taskById(station, taskId)?.messages.any(
            (message) => message.text.contains('fuera del directorio'),
          ) ??
          false;
      if (alreadySaid) return;

      _appendMessage(
        stationId,
        taskId,
        ChatMessage(
          role: ChatRole.error,
          text:
              '${member.name} intentó abrir algo fuera del directorio de '
              'trabajo de la estación. Cambiá el directorio de la estación si '
              'necesita llegar ahí.',
          timestamp: DateTime.now(),
          stepIndex: stepIndex,
        ),
      );
      return;
    }

    // Asking twice for the same tool in the same task is noise — that is the
    // wall of identical denials this replaces.
    final pending = _taskById(station, taskId)?.pendingPermission;
    if (pending?.toolName == request.toolName) return;

    _permissionBlockedProfileByTask[taskId] = member.id;
    _updateTask(
      stationId,
      taskId,
      (task) => task.copyWith(pendingPermission: request),
    );
  }

  /// Your answer to the question above. Granting widens the permission for
  /// every agent — it is an app-level setting, not a per-agent one — and then
  /// puts the blocked member back to work where it stopped.
  Future<void> respondToTaskPermission(
    String stationId,
    String taskId, {
    required bool grant,
  }) async {
    final station = _stationById(stationId);
    if (station == null) return;
    final task = _taskById(station, taskId);
    final request = task?.pendingPermission;
    if (task == null || request == null) return;

    final blockedProfileId = _permissionBlockedProfileByTask.remove(taskId);
    _updateTask(
      stationId,
      taskId,
      (task) => task.copyWith(clearPendingPermission: true),
    );
    if (!grant) return;

    SettingsService.instance.notifier.setExtraToolEnabled(
      request.toolName,
      true,
    );

    final member = membersOf(
      station,
      task: task,
    ).where((profile) => profile.id == blockedProfileId).firstOrNull;
    if (member == null) return;

    await _runMemberTurn(
      stationId: stationId,
      taskId: taskId,
      member: member,
      stepIndex: task.currentStepIndex,
      instruction:
          'Ya tenés permiso para usar ${request.toolName}. Retomá lo que '
          'estabas haciendo desde donde te quedaste.',
    );
  }

  /// Sends a line-scoped question to the member that wrote the file, so the
  /// station answers about code the same way a 1:1 chat does.
  Future<void> askAboutLine(
    String stationId, {
    required String profileId,
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) async {
    final prompt =
        'Sobre el archivo $filePath, línea $lineNumber:\n\n'
        '```\n$lineContent\n```\n\n$question';

    final station = _stationById(stationId);
    if (station == null) return;
    final task = station.activeTask;
    if (task == null) return;
    final member = membersOf(
      station,
      task: task,
    ).where((m) => m.id == profileId).firstOrNull;
    if (member == null) return;

    _appendMessage(
      stationId,
      task.id,
      ChatMessage(
        role: ChatRole.user,
        text: 'Sobre `${filePath.split('/').last}:$lineNumber` — $question',
        timestamp: DateTime.now(),
      ),
    );
    await _runMemberTurn(
      stationId: stationId,
      taskId: task.id,
      member: member,
      stepIndex: task.currentStepIndex,
      instruction: prompt,
    );
  }

  /// Tells the member that owns a file that the user edited it by hand, so the
  /// next turn works from what is actually on disk.
  Future<void> recordManualEdit(
    String stationId, {
    required String profileId,
    required String filePath,
  }) async {
    final station = _stationById(stationId);
    if (station == null) return;
    final task = station.activeTask;
    if (task == null) return;
    final member = membersOf(
      station,
      task: task,
    ).where((m) => m.id == profileId).firstOrNull;
    if (member == null) return;

    _appendMessage(
      stationId,
      task.id,
      ChatMessage(
        role: ChatRole.user,
        text: 'Edité a mano `${filePath.split('/').last}`.',
        timestamp: DateTime.now(),
      ),
    );
    await _runMemberTurn(
      stationId: stationId,
      taskId: task.id,
      member: member,
      stepIndex: task.currentStepIndex,
      instruction:
          'El usuario acaba de editar a mano el archivo $filePath. Leelo de '
          'nuevo antes de seguir y tené en cuenta ese cambio.',
    );
  }

  /// One-off turn outside the step loop: marks the task busy, runs the member,
  /// and settles the task again.
  Future<void> _runMemberTurn({
    required String stationId,
    required String taskId,
    required AgentProfile member,
    required int stepIndex,
    required String instruction,
  }) async {
    _stoppedTaskIds.remove(taskId);
    _updateTask(stationId, taskId, (task) => task.copyWith(isRunning: true));
    await _persist();

    // `finally`, because a turn that throws must still hand the channel back.
    // Otherwise `isRunning` stays true, the composer stays locked, and the
    // only way out is deleting the task.
    try {
      await _runTurn(
        stationId: stationId,
        taskId: taskId,
        member: member,
        stepIndex: stepIndex,
        instruction: instruction,
        consultOfProfileId: null,
        turnId: generateUuidV4(),
        depth: 0,
      );
    } finally {
      _runningTasks.remove(taskId);
      _stoppedTaskIds.remove(taskId);
      _purgeConsultLedgerIfIdle();
      _updateTask(
        stationId,
        taskId,
        (task) => task.copyWith(isRunning: false, clearLiveTurn: true),
      );
      await _persist();
    }
  }

  /// Who takes a follow-up message inside an already-started task. Prefers the
  /// agent that owns the current step; once the workflow has run out of steps
  /// it falls back to whoever spoke last, and finally to any member — a
  /// question inside a task must always land on somebody, never bounce.
  AgentProfile? _followUpOwner(Station station, StationTask task) {
    final workflow = activeWorkflowOf(station);
    if (workflow != null && task.currentStepIndex < workflow.steps.length) {
      final owner = _memberForRole(
        station,
        workflow.steps[task.currentStepIndex].role,
        task: task,
      );
      if (owner != null) return owner;
    }

    final members = membersOf(station, task: task);
    for (var i = task.messages.length - 1; i >= 0; i--) {
      final authorId = task.messages[i].authorProfileId;
      if (authorId == null) continue;
      final author = members.where((m) => m.id == authorId).firstOrNull;
      if (author != null) return author;
    }
    return members.firstOrNull;
  }

  /// Fills in the working directory of a station that arrived without one
  /// (catalog import strips paths on purpose — they're machine-local).
  void setStationWorkingDirectory(String id, String path) {
    _updateStation(id, (station) => station.copyWith(workingDirectory: path));
    unawaited(_persist());
  }

  // ── ejecución de un turno ───────────────────────────────────────────

  /// Runs one CLI turn for [member] and folds its events into the task thread.
  /// After the turn, any `@handle` it wrote is resolved into a consultation
  /// turn, bounded by [_maxConsultDepth] so a chain can't run away.
  Future<void> _runTurn({
    required String stationId,
    required String taskId,
    required AgentProfile member,
    required int stepIndex,
    required String instruction,
    required String? consultOfProfileId,
    required String turnId,
    required int depth,
    bool allowConsults = true,
  }) async {
    final station = _stationById(stationId);
    if (station == null) return;
    if (_stoppedTaskIds.contains(taskId)) return;

    final sessionId = _taskById(
      station,
      taskId,
    )?.sessionsByProfileId[member.id];
    final collector = FileEditCollector();
    final reasoning = StringBuffer();
    final answer = StringBuffer();

    // El mapa de las bases se arma leyendo el disco: si el catálogo todavía
    // no cargó, el turno saldría sin saber que existen. Acá sí se puede
    // esperar — `_turnSystemPrompt` es síncrono a propósito.
    await KnowledgeService.instance.notifier.ready;

    // The member's assigned executable tools travel as a per-turn MCP
    // config — the loopback server runs in the main isolate, and the CLI
    // subprocess reaches it over 127.0.0.1 regardless of which isolate
    // spawned it.
    // Codex has no per-turn tools/MCP surface — those stay empty for it.
    final isCodex = member.provider == AgentProvider.codex;
    final memberTools = isCodex
        ? const <Tool>[]
        : ToolsService.instance.notifier.toolsByNames(member.tools);
    final toolsEntry = memberTools.isEmpty
        ? null
        : UserToolsMcpServer.mcpServerEntryFor(
            member.id,
            workingDirectory: station.workingDirectory,
          );
    final externalServers = isCodex
        ? const <McpServerConfig>[]
        : McpServersService.instance.notifier.serversByNames(
            member.mcpServers,
          );
    final externalSecretValues = SecretsService.instance.notifier.valuesFor([
      for (final server in externalServers) ...server.secretNames,
    ]);
    // El plan de la tarea va en TODOS los turnos de estación, sin depender
    // de que el perfil tenga tools asignadas: es del canal, no del agente.
    final planEntry = isCodex
        ? null
        : TaskPlanMcpServer.mcpServerEntryFor(
            stationId: stationId,
            taskId: taskId,
            profileId: member.id,
          );
    final mcpServers = <String, dynamic>{
      kUserToolsMcpServerKey: ?toolsEntry,
      kTaskPlanMcpServerKey: ?planEntry,
      for (final server in externalServers)
        server.name: server.toMcpServerEntry(externalSecretValues),
    };

    final run = await TaskRunner.run(
      TaskRunSpec(
        prompt: instruction,
        workingDirectory: station.workingDirectory,
        model: member.model,
        fullFileSystemAccess: false,
        effort: member.effort,
        extraAllowedTools: [
          ...SettingsService.instance.notifier.data.extraAllowedTools,
          if (planEntry != null) ...kTaskPlanMcpToolNames,
          if (toolsEntry != null)
            ...memberTools.map(
              (tool) => '$kUserToolsMcpToolPrefix${tool.name}',
            ),
          ...externalServers.map((server) => 'mcp__${server.name}'),
        ],
        sessionId: sessionId,
        additionalSystemPrompt: _turnSystemPrompt(
          station,
          member,
          task: _taskById(station, taskId),
        ),
        mcpConfig: mcpServers.isEmpty
            ? null
            : jsonEncode({'mcpServers': mcpServers}),
        provider: member.provider.alias,
      ),
    );
    _runningTasks[taskId] = run;
    // The channel is shared, so the live strip has to say *who* is working.
    _updateTask(
      stationId,
      taskId,
      (task) => task.copyWith(liveTurn: TaskLiveTurn(profileId: member.id)),
    );

    await for (final event in run.events) {
      if (_stoppedTaskIds.contains(taskId)) break;

      switch (event) {
        case TaskSessionStarted(sessionId: final id):
          _updateTask(stationId, taskId, (task) {
            final sessions = Map<String, String>.from(task.sessionsByProfileId);
            sessions[member.id] = id;
            return task.copyWith(sessionsByProfileId: sessions);
          });

        case TaskAssistantText(text: final chunk):
          answer.write(chunk);
          _appendMessage(
            stationId,
            taskId,
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
            stationId,
            taskId,
            (turn) => turn.copyWith(
              clearReasoning: true,
              clearActivity: true,
              phase: TurnPhase.writing,
            ),
          );

        case TaskToolUse(name: final name, input: final input):
          _updateLiveTurn(
            stationId,
            taskId,
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
            stationId,
            taskId,
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
            _updateTask(stationId, taskId, (task) {
              final costs = Map<String, double>.from(task.costByProfileId);
              costs[member.id] = (costs[member.id] ?? 0) + costUsd;
              return task.copyWith(
                costUsd: task.costUsd + costUsd,
                costByProfileId: costs,
              );
            });
          }
          if (isError) {
            _appendMessage(
              stationId,
              taskId,
              ChatMessage(
                role: ChatRole.error,
                text: 'claude reportó un error en el turno de ${member.name}.',
                timestamp: DateTime.now(),
                stepIndex: stepIndex,
              ),
            );
          } else {
            _annotateLastMessage(
              stationId,
              taskId,
              costUsd: costUsd,
              durationMs: durationMs,
            );
          }

        case TaskPermissionDenied(
          toolName: final toolName,
          message: final message,
        ):
          _handlePermissionDenied(
            stationId: stationId,
            taskId: taskId,
            member: member,
            stepIndex: stepIndex,
            request: PermissionRequest(toolName: toolName, message: message),
          );

        case TaskContextUsage(
          usedTokens: final usedTokens,
          contextWindowTokens: final windowTokens,
        ):
          _updateTask(
            stationId,
            taskId,
            (task) => task.copyWith(
              contextUsedTokens: usedTokens,
              contextWindowTokens: windowTokens,
            ),
          );

        case TaskFailure(message: final message):
          _appendMessage(
            stationId,
            taskId,
            ChatMessage(
              role: ChatRole.error,
              text: message,
              timestamp: DateTime.now(),
              stepIndex: stepIndex,
            ),
          );
      }
    }

    _runningTasks.remove(taskId);
    _updateTask(
      stationId,
      taskId,
      (task) => task.copyWith(clearLiveTurn: true),
    );
    await _persist();

    // Before the consult pass, so a specialist declared in this answer is a
    // real member by the time the same answer mentions its @handle.
    await _registerDeclaredAgents(
      stationId: stationId,
      taskId: taskId,
      author: member,
      text: answer.toString(),
      stepIndex: stepIndex,
    );

    if (!allowConsults || depth >= _maxConsultDepth) return;
    await _resolveConsultations(
      stationId: stationId,
      taskId: taskId,
      asker: member,
      stepIndex: stepIndex,
      text: answer.toString(),
      turnId: turnId,
      depth: depth,
    );
  }

  /// Registers every agent [author] declared in [text] and adds it to the
  /// station, so the specialist it asked for exists for real — with its specs
  /// visible, its creator recorded, and a line in the thread saying so —
  /// instead of running as a subagent nobody can inspect.
  Future<void> _registerDeclaredAgents({
    required String stationId,
    required String taskId,
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
          stationId,
          taskId,
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
            stationId,
            taskId,
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
      // Scoped to THIS task, not the station: a specialist an agent pulls in
      // mid-conversation exists for that conversation. Making it a standing
      // member is the user's call, from the station form.
      addAgentToTask(stationId, taskId, registeredId);

      _appendMessage(
        stationId,
        taskId,
        ChatMessage(
          role: ChatRole.assistant,
          text: existing == null
              ? '${author.name} incorporó a **@$handle** '
                    '(${fields['rol'] ?? handle}) a ESTA tarea.'
                    '${fields['proposito'] == null ? '' : '\n\n${fields['proposito']}'}'
              : '${author.name} sumó a **@$handle**, que ya estaba '
                    'registrado, a esta tarea.',
          timestamp: DateTime.now(),
          authorProfileId: author.id,
          stepIndex: stepIndex,
        ),
      );
    }
    await _persist();
  }

  /// Turns every `@handle` [asker] wrote into a turn for that member, then
  /// hands the answer back to [asker] so it can continue its own step.
  Future<void> _resolveConsultations({
    required String stationId,
    required String taskId,
    required AgentProfile asker,
    required int stepIndex,
    required String text,
    required String turnId,
    required int depth,
  }) async {
    final station = _stationById(stationId);
    if (station == null) return;

    final members = membersOf(station, task: _taskById(station, taskId));
    final asked = <String>{};

    for (final match in _mentionPattern.allMatches(text)) {
      if (_stoppedTaskIds.contains(taskId)) return;

      final handle = match.group(1);
      if (handle == null || handle == asker.name) continue;
      if (!asked.add(handle)) continue;

      final target = members.where((m) => m.name == handle).firstOrNull;
      if (target == null) continue;

      // One consult per pair per turn — see [_consultedPairs].
      final pair = '$turnId:${asker.id}>${target.id}';
      if (!_consultedPairs.add(pair)) continue;

      await _runTurn(
        stationId: stationId,
        taskId: taskId,
        member: target,
        stepIndex: stepIndex,
        instruction: _consultPrompt(asker, text),
        consultOfProfileId: asker.id,
        turnId: turnId,
        depth: depth + 1,
      );

      final current = _stationById(stationId);
      final answered = current == null
          ? null
          : _taskById(current, taskId)?.messages.lastOrNull;
      if (answered == null) continue;

      // The asker's continuation must NOT open new consults. Otherwise a
      // courteous sign-off that names the other agent ("quedo a la espera de
      // @revision") is read as a fresh question, and the two of them
      // ping-pong confirmations at real cost.
      await _runTurn(
        stationId: stationId,
        taskId: taskId,
        member: asker,
        stepIndex: stepIndex,
        instruction: _consultAnswerPrompt(target, answered.text),
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
    String request,
  ) {
    return 'Lo que pidió el usuario en este canal:\n$request\n\n'
        'Estás ejecutando el paso ${index + 1} de ${workflow.steps.length} '
        'del flujo "${workflow.name}": ${step.title}.\n'
        '${step.instruction}\n\n'
        'Hacé únicamente lo que corresponde a este paso; los demás pasos los '
        'ejecutan tus compañeros.';
  }

  String _consultPrompt(AgentProfile asker, String text) {
    return '@${asker.name} (${asker.role}) te consultó en el canal:\n\n$text\n\n'
        'Respondé la consulta desde tu especialidad. Si para responder tenés '
        'que corregir algo en tu área, podés hacerlo.';
  }

  String _consultAnswerPrompt(AgentProfile target, String answer) {
    return '@${target.name} respondió tu consulta:\n\n$answer\n\n'
        'Seguí con tu paso usando esa respuesta.';
  }

  /// Composes what this member knows for the whole turn: the global skills
  /// every agent carries, who it is, the station's shared rules and
  /// documents, and who else it can consult.
  String _turnSystemPrompt(
    Station station,
    AgentProfile member, {
    StationTask? task,
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
    final ruleNames = {...member.rules, ...station.ruleNames};
    for (final name in ruleNames) {
      final rule = rules.where((r) => r.name == name).firstOrNull;
      if (rule == null || rule.content.isEmpty) {
        Log.w(
          'Rule "$name" referenced by station "${station.name}" not found or empty',
        );
        continue;
      }
      buffer.writeln();
      buffer.writeln(rule.content);
    }

    final saber = KnowledgeService.instance.notifier.briefFor(<String>{
      ...station.knowledgeBaseNames,
      ...member.knowledgeBaseNames,
    }.toList());
    if (saber.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(saber);
    }

    final companions = membersOf(
      station,
      task: task,
    ).where((m) => m.id != member.id).toList();
    if (companions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        'Estás trabajando en la estación "${station.name}"'
        '${station.purpose.isEmpty ? '' : ' — ${station.purpose}'}. '
        'Tus compañeros en el canal son:',
      );
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
        'Cuando consultes, formulá SOLO la pregunta concreta con el mínimo '
        'contexto necesario — no pegues todo tu razonamiento ni el historial: '
        'cada palabra de más se paga en el turno del otro.',
      );
    }

    buffer.writeln();
    buffer.writeln(_planPrompt);

    buffer.writeln();
    buffer.writeln(_noBackgroundWorkPrompt);

    final combined = buffer.toString().trim();
    return combined;
  }

  // ── helpers de estado ───────────────────────────────────────────────

  Station? _stationById(String id) {
    for (final station in data.stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  Workflow? activeWorkflowOf(Station station) {
    final id = station.activeWorkflowId;
    if (id == null) return null;
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    return workflows.where((workflow) => workflow.id == id).firstOrNull;
  }

  /// The roster a turn sees: the station's members plus [task]'s own
  /// extras. Extras are per-task by design — the station is untouched.
  List<AgentProfile> membersOf(Station station, {StationTask? task}) {
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    final ids = <String>{
      ...station.profileIds,
      ...?task?.extraProfileIds,
    };
    return ids
        .map((id) => profiles.where((p) => p.id == id).firstOrNull)
        .whereType<AgentProfile>()
        .toList();
  }

  /// Adds a registered profile to ONE task's roster. No-op if it's already
  /// a member (of the station or the task).
  void addAgentToTask(String stationId, String taskId, String profileId) {
    final station = _stationById(stationId);
    if (station == null) return;
    if (station.profileIds.contains(profileId)) return;

    _updateTask(stationId, taskId, (task) {
      if (task.extraProfileIds.contains(profileId)) return task;
      return task.copyWith(
        extraProfileIds: [...task.extraProfileIds, profileId],
      );
    });
    unawaited(_persist());
  }

  /// Removes a TASK-scoped extra. Station members can't be removed from
  /// here — that's the station form's job.
  void removeAgentFromTask(String stationId, String taskId, String profileId) {
    _updateTask(stationId, taskId, (task) {
      return task.copyWith(
        extraProfileIds: task.extraProfileIds
            .where((id) => id != profileId)
            .toList(),
      );
    });
    unawaited(_persist());
  }

  int stepCountFor(Station station) {
    return activeWorkflowOf(station)?.steps.length ?? 0;
  }

  AgentProfile? _memberForRole(
    Station station,
    String role, {
    StationTask? task,
  }) {
    return memberForRole(membersOf(station, task: task), role);
  }

  String _titleFor(String request) {
    final firstLine = request.split('\n').first.trim();
    if (firstLine.length <= 48) return firstLine;
    return '${firstLine.substring(0, 45)}…';
  }

  StationTask? _taskById(Station station, String taskId) {
    for (final task in station.tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  void _finishTask(String stationId, String taskId, StationTaskStatus status) {
    _runningTasks.remove(taskId);
    _purgeConsultLedgerIfIdle();
    _updateTask(
      stationId,
      taskId,
      (task) =>
          task.copyWith(status: status, isRunning: false, clearLiveTurn: true),
    );
  }

  void _appendMessage(String stationId, String taskId, ChatMessage message) {
    _updateTask(
      stationId,
      taskId,
      (task) => task.copyWith(messages: [...task.messages, message]),
    );
  }

  void _annotateLastMessage(
    String stationId,
    String taskId, {
    required double costUsd,
    required int durationMs,
  }) {
    _updateTask(stationId, taskId, (task) {
      final messages = [...task.messages];
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
      return task.copyWith(messages: messages);
    });
  }

  /// Narrows [_updateTask] to the turn in flight, so a chunk that arrives
  /// after the turn ended is dropped instead of resurrecting a dead strip.
  void _updateLiveTurn(
    String stationId,
    String taskId,
    TaskLiveTurn Function(TaskLiveTurn turn) update,
  ) {
    _updateTask(stationId, taskId, (task) {
      final turn = task.liveTurn;
      if (turn == null) return task;
      return task.copyWith(liveTurn: update(turn));
    });
  }

  void _updateTask(
    String stationId,
    String taskId,
    StationTask Function(StationTask task) transform,
  ) {
    _updateStation(stationId, (station) {
      final tasks = station.tasks
          .map((task) => task.id == taskId ? transform(task) : task)
          .toList();
      return station.copyWith(tasks: tasks);
    });
  }

  void _updateStation(
    String stationId,
    Station Function(Station station) transform,
  ) {
    final stations = data.stations
        .map(
          (station) => station.id == stationId ? transform(station) : station,
        )
        .toList();
    updateState(data.copyWith(stations: stations));
  }

  Future<void> _persist() => _repository.save(data.stations);
}

mixin StationsService {
  static final ReactiveNotifier<StationsViewModel> instance =
      ReactiveNotifier<StationsViewModel>(() => StationsViewModel());
}
