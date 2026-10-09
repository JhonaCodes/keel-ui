import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/l10n/generated/app_localizations_en.dart';
import 'package:keel_ui/l10n/generated/app_localizations_es.dart';

import 'package:keel_core/integrations/task_runner/task_runner.dart';
import 'package:keel_core/core/services/cli_turn_contract.dart';
import 'package:keel_core/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_core/integrations/machine/machine.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_core/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_core/integrations/context_mcp/context_mcp_server.dart';
import 'package:keel_core/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_core/modules/agents/service/remote_conversation_history.dart';
import 'package:keel_core/modules/agents/model/file_edit.dart';
import 'package:keel_core/modules/agents/model/line_diff.dart';
import 'package:keel_core/modules/agents/model/permission_request.dart';
import 'package:keel_core/modules/agents/model/plan_decision.dart';
import 'package:keel_core/modules/agents/model/queued_message.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/model_catalog_viewmodel.dart';
import 'package:keel_core/modules/agents/repository/agents_repository.dart';
import 'package:keel_core/integrations/decisions_mcp/decisions_mcp_server.dart';
import 'package:keel_core/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_core/integrations/chat_references/chat_references.dart';
import 'package:keel_core/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/integrations/workspace_roots/workspace_roots.dart';
// keel-debt: `composeTurnSystemPrompt` vive bajo `modules/projects/` y lo
// usan los dos caminos de turno. Su lugar natural es
// `integrations/system_prompt/`; se mueve cuando nadie más lo esté editando.
import 'package:keel_core/modules/projects/service/turn_prompt.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_core/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_core/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_core/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_core/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_executor.dart';
import 'package:keel_core/modules/assistant/service/assistant_action_parser.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_core/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_core/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_core/shared/shared.dart';

class AgentsViewModel extends ViewModel<AgentsState> {
  AgentsViewModel() : super(const AgentsState());

  AgentsRepository get _repository => AgentsRepository();

  /// El turno en vuelo de cada agente. Es un [TaskRun] y no un [Process]
  /// porque el proceso ya no vive de este lado: corre en otro isolate, que
  /// es lo que saca del hilo de la interfaz el parseo de cada línea del
  /// stream —el trabajo que ponía la app pastosa mientras se conversaba.
  final Map<String, TaskRun> _runningTurns = {};
  final Map<String, Completer<CatalogPermissionOutcome>>
  _catalogChangePermissions = {};

  /// Turns suspended in Keel's permission gate, by agent: the hook of a
  /// codex (or API) turn is waiting on this answer.
  final Map<String, Completer<({bool allow, bool always})>> _toolGates = {};

  /// One card at a time per chat: a second gate request waits for the first
  /// to be answered instead of replacing it.
  final Map<String, Future<void>> _toolGateQueue = {};

  /// Guardar de a un agente y de a ráfagas.
  ///
  /// Casi todo lo que pasa acá cambia UN agente: llega un pedazo de texto, se
  /// marca el modelo, se contesta un permiso. Hacerlo con [_persist]
  /// reescribía la lista entera —cada agente con todos sus mensajes, y cada
  /// mensaje con el contenido completo de los archivos que tocó— con una
  /// llamada FFI bloqueante por registro, sobre el hilo de la interfaz.
  late final _writes = CoalescedWrites(
    window: const Duration(milliseconds: 400),
    write: (agentId) async {
      final agent = data.agents
          .where((agent) => agent.id == agentId)
          .firstOrNull;
      // Borrado mientras esperaba: `deleteAgent` ya reescribió el conjunto.
      if (agent != null) await _repository.saveOne(agent);
    },
  );

  /// Pid → agente, para poder despublicarlo de la pantalla de Máquina.
  final Map<String, int> _runningPids = {};

  /// Turns the user stopped, by run and not by agent: «Enviar ahora» starts
  /// the agent's next turn right away, and a mark kept by agent was taken by
  /// that new turn, which then died as stopped on its first event.
  final Set<TaskRun> _stoppedRuns = {};

  /// Messages handed to a turn in flight that have no acknowledgment yet
  /// ([TaskSteerDelivered]), by run and by the text that travelled. Whatever
  /// is still here when the turn ends never entered: it goes back to the
  /// queue.
  final Map<TaskRun, Map<String, QueuedMessage>> _unconfirmedSteers = {};

  /// Dónde corre un agente 1:1: su casa, porque no tiene proyecto asignado.
  /// Sirve además para resolver las rutas relativas que reporte su CLI.
  String get looseAgentWorkingDirectory =>
      Platform.environment['HOME'] ?? Directory.current.path;

  @override
  void init() {
    updateSilently(const AgentsState());
    unawaited(_loadPersistedAgents());
  }

  Future<void> _loadPersistedAgents() async {
    try {
      final agents = await _repository.load();
      updateState(data.copyWith(agents: agents));
    } catch (error) {
      Log.e('Failed to load persisted agents', error: error);
    }
  }

  void createAgent(
    String name, {
    required String model,
    required bool fullFileSystemAccess,
    required String effort,
    AgentProvider provider = AgentProvider.claude,
    String? profileId,
  }) {
    final agent = _buildAgent(
      name,
      model: model,
      fullFileSystemAccess: fullFileSystemAccess,
      effort: effort,
      provider: provider,
      profileId: profileId,
    );
    final agents = [...data.agents, agent];
    updateState(data.copyWith(agents: agents, selectedAgentId: agent.id));
    // Una clave nueva: no hay nada viejo que sacar, así que no hace falta
    // reescribir la lista entera.
    unawaited(_repository.saveOne(agent));
  }

  /// Same as [createAgent], but leaves [AgentsState.selectedAgentId] alone.
  /// The main window's content area reads that field to decide what's on
  /// screen — a caller managing its own session outside that focus (e.g. the
  /// Assistant panel) must not change what's showing behind it just by
  /// starting a conversation. Returns the new agent's id.
  String createAgentSilently(
    String name, {
    required String model,
    required bool fullFileSystemAccess,
    required String effort,
    AgentProvider provider = AgentProvider.claude,
    String? profileId,
  }) {
    final agent = _buildAgent(
      name,
      model: model,
      fullFileSystemAccess: fullFileSystemAccess,
      effort: effort,
      provider: provider,
      profileId: profileId,
    );
    final agents = [...data.agents, agent];
    updateState(data.copyWith(agents: agents));
    unawaited(_repository.saveOne(agent));
    return agent.id;
  }

  Agent _buildAgent(
    String name, {
    required String model,
    required bool fullFileSystemAccess,
    required String effort,
    AgentProvider provider = AgentProvider.claude,
    String? profileId,
  }) {
    return Agent(
      id: generateUuidV4(),
      name: name,
      model: model,
      provider: provider,
      createdAt: DateTime.now(),
      fullFileSystemAccess: fullFileSystemAccess,
      iconColorValue: suggestNextIconColor().toARGB32(),
      effort: effort,
      profileId: profileId,
    );
  }

  AgentProfile? _keelAiProfile() => AgentProfilesService
      .instance
      .notifier
      .data
      .profiles
      .where((profile) => profile.name == kKeelAiHandle)
      .firstOrNull;

  /// Finds the most recent conversation with the reserved Keel AI profile,
  /// or starts one if none exists. Null only if the profile itself hasn't
  /// been seeded yet, which shouldn't happen after `main()`'s startup.
  ///
  /// Call this from an event handler (a button's `onPressed`), never from a
  /// widget's `build`/`initState` — starting a session can mutate this
  /// ViewModel's state via [createAgentSilently], and any part of the
  /// widget-tree build phase (including `initState`, which still runs
  /// inside it) is not a safe place for that: it trips "setState() or
  /// markNeedsBuild() called during build" on every OTHER already-mounted
  /// listener of this same notifier.
  String? resolveKeelAiSession() {
    final profile = _keelAiProfile();
    if (profile == null) return null;

    final sessions =
        data.agents.where((agent) => agent.profileId == profile.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions.isNotEmpty
        ? sessions.first.id
        : _startKeelAiSession(profile);
  }

  /// Always starts a fresh Keel AI conversation. Same call-site restriction
  /// as [resolveKeelAiSession].
  String? startNewKeelAiSession() {
    final profile = _keelAiProfile();
    if (profile == null) return null;
    return _startKeelAiSession(profile);
  }

  String _startKeelAiSession(AgentProfile profile) {
    return createAgentSilently(
      profile.name,
      model: profile.model,
      fullFileSystemAccess: false,
      effort: profile.effort,
      provider: profile.provider,
      profileId: profile.id,
    );
  }

  Color suggestNextIconColor() =>
      nextAgentIconColor(data.agents.map((agent) => agent.iconColor));

  void selectAgent(String id) {
    updateState(data.copyWith(selectedAgentId: id));
    unawaited(warmUp(id));
  }

  void setAgentModel(String agentId, String model) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].model == model) return;

    _updateAgent(agentId, (agent) => agent.copyWith(model: model));
    _writes.schedule(agentId);
    unawaited(warmUp(agentId));
  }

  void setAgentProvider(String agentId, AgentProvider provider) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].provider == provider) return;

    _updateAgent(
      agentId,
      (agent) =>
          agent.copyWith(provider: provider, model: defaultModelFor(provider)),
    );
    _writes.schedule(agentId);
    // A process started for the previous provider has nothing left to do.
    TaskRunner.closeLive(agentId);
    unawaited(warmUp(agentId));
  }

  void setAgentEffort(String agentId, String effort) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].effort == effort) return;

    _updateAgent(agentId, (agent) => agent.copyWith(effort: effort));
    _writes.schedule(agentId);
    unawaited(warmUp(agentId));
  }

  void setAgentFullFileSystemAccess(String agentId, bool enabled) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(fullFileSystemAccess: enabled),
    );
    _writes.schedule(agentId);
    unawaited(warmUp(agentId));
  }

  /// Prende o apaga el modo plan de esta conversación.
  ///
  /// Cambiarlo también baja la tarjeta pendiente: si estabas decidiendo si
  /// implementar un plan y tocaste el modo, ya decidiste otra cosa.
  void setAgentPlanMode(String agentId, bool enabled) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].planMode == enabled) return;

    _updateAgent(
      agentId,
      (agent) => agent.copyWith(planMode: enabled, planAwaitingDecision: false),
    );
    _writes.schedule(agentId);
    unawaited(warmUp(agentId));
  }

  /// El plan quedó aprobado: sale del modo plan y arranca a implementarlo.
  ///
  /// El pedido entra al hilo como mensaje del usuario porque eso es: la
  /// decisión la tomó una persona, y el hilo tiene que mostrar quién pidió
  /// qué. Y lleva el plan escrito adentro, no solo la confianza en el
  /// `--resume`: si la sesión del CLI se cayó y hay que reintentar sin
  /// resume, un agente que lee «implementá lo acordado» sin saber qué se
  /// acordó implementa cualquier cosa, en silencio.
  void implementPlan(String agentId) {
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null || !target.planAwaitingDecision) return;

    final plan = target.messages
        .where((message) => message.role == ChatRole.assistant)
        .lastOrNull
        ?.text
        .trim();

    _updateAgent(
      agentId,
      (agent) => agent.copyWith(planMode: false, planAwaitingDecision: false),
    );
    _writes.schedule(agentId);

    unawaited(sendMessage(agentId, planApprovalRequest(plan)));
  }

  /// Baja la tarjeta y deja el modo plan prendido: seguir planificando es
  /// quedarse donde estabas, no volver atrás.
  void keepPlanning(String agentId) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || !data.agents[index].planAwaitingDecision) return;

    _updateAgent(
      agentId,
      (agent) => agent.copyWith(planAwaitingDecision: false),
    );
  }

  void respondToPermissionRequest(
    String agentId, {
    required bool grant,
    bool always = false,
  }) {
    // Sin `orElse`: contestar el pedido de un agente que se borró mientras
    // la tarjeta estaba en pantalla tiraba una excepción en el tap.
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    final request = target?.pendingPermission;
    if (request == null) return;

    _updateAgent(
      agentId,
      (agent) => agent.copyWith(clearPendingPermission: true),
    );
    if (request.blocking) {
      // The turn is still alive, waiting in the gate: the answer goes back
      // to it. No follow-up message — the tool simply runs, or doesn't.
      final gate = _toolGates.remove(agentId);
      if (gate != null && !gate.isCompleted) {
        gate.complete((allow: grant, always: grant && always));
      }
      return;
    }
    if (request.isCatalogChange) {
      final pending = _catalogChangePermissions.remove(agentId);
      if (pending != null && !pending.isCompleted) {
        pending.complete(
          grant
              ? CatalogPermissionOutcome.approved
              : CatalogPermissionOutcome.denied,
        );
      }
      return;
    }
    if (!grant) return;

    if (request.isSandboxRestriction) {
      setAgentFullFileSystemAccess(agentId, true);
    } else {
      SettingsService.instance.notifier.setExtraToolEnabled(
        request.toolName,
        true,
      );
    }

    unawaited(
      sendMessage(
        agentId,
        'Ya tienes permiso para usar ${request.toolName}, continúa.',
      ),
    );
  }

  /// Suspende una escritura del catálogo hasta que la persona conteste.
  ///
  /// **No tiene plazo, y eso es el punto.** Antes esperaba diez minutos y
  /// después daba el pedido por caído; abajo de eso, el servidor MCP cortaba
  /// la respuesta HTTP a los treinta segundos. O sea que el reloj que
  /// mandaba era uno que nadie veía: te demorabas un minuto en leer qué te
  /// estaban pidiendo, el modelo ya había recibido «la tool falló», y tu
  /// aprobación llegaba a un teléfono descolgado — la escritura se hacía,
  /// pero del otro lado nadie la escuchaba.
  ///
  /// Un permiso no caduca. Lo terminan dos cosas: que contestes, o que el
  /// turno que lo pidió deje de existir ([stopAgent]).
  Future<CatalogPermissionOutcome> requestCatalogChangePermission({
    required String agentId,
    required String kind,
    required String name,
    required String intent,
    required String reason,
  }) async {
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null) return CatalogPermissionOutcome.cancelled;
    // Dos tarjetas a la vez no se pueden mostrar, así que el segundo pedido
    // no se puede atender. Decirlo como «pendiente» y no como «rechazado»
    // importa: rechazado significa que alguien lo miró y dijo que no.
    if (target.pendingPermission != null) {
      return CatalogPermissionOutcome.busy;
    }

    final completer = Completer<CatalogPermissionOutcome>();
    _catalogChangePermissions[agentId] = completer;
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        pendingPermission: PermissionRequest(
          toolName: 'catalog_lock',
          message: 'Keel AI pidió modificar un elemento bloqueado.',
          kind: kind,
          itemName: name,
          changeIntent: intent,
          changeReason: reason,
          requestedBy: agent.name,
        ),
      ),
    );
    try {
      return await completer.future;
    } finally {
      if (_catalogChangePermissions[agentId] == completer) {
        _catalogChangePermissions.remove(agentId);
        _updateAgent(
          agentId,
          (agent) => agent.copyWith(clearPendingPermission: true),
        );
      }
    }
  }

  /// Corta un permiso pendiente porque el turno que lo pidió se terminó.
  ///
  /// Es la contracara de no tener plazo: sin esto, sacar el reloj cambiaría
  /// «expira solo» por «queda colgado para siempre».
  void _cancelPendingPermission(String agentId) {
    final pending = _catalogChangePermissions.remove(agentId);
    if (pending != null && !pending.isCompleted) {
      pending.complete(CatalogPermissionOutcome.cancelled);
    }
    final gate = _toolGates.remove(agentId);
    if (gate != null && !gate.isCompleted) {
      gate.complete((allow: false, always: false));
    }
  }

  /// What Keel's permission gate answers before a tool that writes or runs
  /// something in a 1:1 chat. A tool granted "always" passes at once;
  /// anything else puts a card in the chat and WAITS — the provider's
  /// process stays suspended in the hook until the person answers or stops
  /// the turn. Same contract as `ProjectsViewModel.decideToolUse`.
  Future<({bool allow, String reason})> decideToolUse({
    required String agentId,
    required String toolName,
    required String toolInput,
  }) async {
    final previous = _toolGateQueue[agentId];
    final turnInQueue = Completer<void>();
    _toolGateQueue[agentId] = turnInQueue.future;
    try {
      await previous;
      return await _askToolGate(
        agentId: agentId,
        toolName: toolName,
        toolInput: toolInput,
      );
    } finally {
      turnInQueue.complete();
      if (identical(_toolGateQueue[agentId], turnInQueue.future)) {
        _toolGateQueue.remove(agentId);
      }
    }
  }

  Future<({bool allow, String reason})> _askToolGate({
    required String agentId,
    required String toolName,
    required String toolInput,
  }) async {
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null) {
      return (allow: false, reason: 'Keel no reconoce este chat.');
    }
    if (SettingsService.instance.notifier.data.extraAllowedTools.contains(
      toolName,
    )) {
      return (allow: true, reason: '');
    }
    if (!target.isStreaming) {
      return (allow: false, reason: 'El turno ya no está corriendo.');
    }
    if (target.pendingPermission != null) {
      return (
        allow: false,
        reason: 'Hay otro pedido esperando respuesta en este chat.',
      );
    }

    final gate = Completer<({bool allow, bool always})>();
    _toolGates[agentId] = gate;
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        pendingPermission: PermissionRequest(
          toolName: toolName,
          message: toolInput.isEmpty
              ? '@${agent.name} quiere usar $toolName.'
              : '@${agent.name} quiere usar $toolName:\n$toolInput',
          blocking: true,
        ),
      ),
    );
    try {
      final answer = await gate.future;
      if (answer.always) {
        SettingsService.instance.notifier.setExtraToolEnabled(toolName, true);
      }
      return answer.allow
          ? (allow: true, reason: '')
          : (allow: false, reason: 'La persona lo rechazó desde Keel.');
    } finally {
      if (identical(_toolGates[agentId], gate)) _toolGates.remove(agentId);
      _updateAgent(
        agentId,
        (agent) => agent.pendingPermission?.blocking ?? false
            ? agent.copyWith(clearPendingPermission: true)
            : agent,
      );
    }
  }

  void deleteAgent(String id) {
    TaskRunner.closeLive(id);
    final agents = data.agents.where((agent) => agent.id != id).toList();
    final selectedAgentId = data.selectedAgentId == id
        ? null
        : data.selectedAgentId;
    updateState(AgentsState(agents: agents, selectedAgentId: selectedAgentId));
    // Borrar sí necesita reescribir todo: es lo único que saca una clave de
    // la base, y de paso cancela lo que quedara en la cola de escritura.
    unawaited(_persist());
  }

  void deleteMessage(String agentId, DateTime timestamp) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        messages: agent.messages
            .where((message) => message.timestamp != timestamp)
            .toList(),
      ),
    );
    _writes.schedule(agentId);
  }

  void requestCompact(String agentId) {
    unawaited(sendMessage(agentId, '/compact'));
  }

  void stopAgent(String agentId) {
    final run = _runningTurns.remove(agentId);
    if (run == null) return;
    final pid = _runningPids.remove(agentId);
    if (pid != null) RunningProcesses.unregister(pid);

    _stoppedRuns.add(run);
    run.cancel();
    // El turno que pedía el permiso ya no existe: aprobarlo no escribiría
    // nada, así que la tarjeta se va y quien esperaba recibe «cancelado».
    _cancelPendingPermission(agentId);

    _setCurrentActivity(agentId, null);
    _updateAgent(agentId, (agent) => agent.copyWith(clearLiveReasoning: true));
    _appendMessage(
      agentId,
      ChatMessage(
        role: ChatRole.error,
        text: 'Detenido por el usuario.',
        timestamp: DateTime.now(),
      ),
    );
    _setStreaming(agentId, false);
    _writes.schedule(agentId);
  }

  void recordManualEdit(String agentId, FileEdit edit) {
    _updateAgent(agentId, (agent) => agent.copyWith(pendingUserEdit: edit));
  }

  Future<void> askAboutLine(
    String agentId, {
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) {
    final fileName = filePath.split('/').last;
    return sendMessage(
      agentId,
      'Sobre el archivo $fileName ($filePath), línea $lineNumber:\n'
      '```\n$lineContent\n```\n'
      'Pregunta: $question',
    );
  }

  /// [imagePaths] are attachments already stored by [ChatAttachmentStore].
  /// A message carrying only images and no text is legitimate — dropping a
  /// screenshot and hitting send is the whole point of the feature.
  Future<void> sendMessage(
    String agentId,
    String text, {
    List<String> imagePaths = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePaths.isEmpty) return;

    final target = data.agents.firstWhere((agent) => agent.id == agentId);
    // Mid-turn: the message waits in the queue and goes out as the next turn
    // instead of the composer refusing it. «Enviar ahora» hands it to the
    // turn in flight when its provider takes one (see sendQueuedMessageNow).
    if (target.isStreaming) {
      _updateAgent(
        agentId,
        (agent) => agent.copyWith(
          queuedMessages: [
            ...agent.queuedMessages,
            QueuedMessage(text: trimmed, imagePaths: imagePaths),
          ],
        ),
      );
      return;
    }

    final pendingUserEdit = target.pendingUserEdit;
    if (pendingUserEdit != null) {
      _updateAgent(
        agentId,
        (agent) => agent.copyWith(clearPendingUserEdit: true),
      );
    }

    // The message and the progress bar show up NOW. Everything below —
    // references, catalogs, hooks, the CLI process — used to run first, and
    // the chat looked frozen for seconds with nothing to say it was working.
    _appendMessage(
      agentId,
      ChatMessage(
        role: ChatRole.user,
        text: trimmed,
        timestamp: DateTime.now(),
        imagePaths: imagePaths,
      ),
    );
    // Zero-token recurrence detector — never in the send critical path.
    unawaited(PromptInsightsService.instance.notifier.record(trimmed));
    // Mandar algo reemplaza la decisión anterior: si había una tarjeta de
    // «¿implementamos?» flotando, el mensaje nuevo es la respuesta.
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(planAwaitingDecision: false),
    );
    _setStreaming(agentId, true);
    _writes.schedule(agentId);

    final TaskRun run;
    try {
      final promptForModel = await _promptForModel(
        trimmed,
        imagePaths,
        pendingUserEdit: pendingUserEdit,
      );

      final setup = await _prepareTurn(target, prompt: promptForModel);
      for (final note in setup.hookNotes) {
        appendTurnNotice(agentId, note);
      }
      // UN solo camino para correr un turno, y corre en otro isolate.
      //
      // Antes esto tenía dos: `ClaudeCliService` y `CodexCliService`, ambos
      // en el hilo de la interfaz, decodificando cada línea del stream
      // —incluidos resultados de herramienta de cientos de KB— entre frame y
      // frame. Los proyectos ya usaban el task runner; el chat 1:1 y Keel AI
      // se habían quedado atrás, que es por qué la app se ponía pastosa
      // justo mientras se conversaba con el asistente.
      //
      // Claude keeps ONE process per conversation, like Claude Code: the
      // turn only waits for the model, not for a CLI to boot.
      run = TaskRunner.supportsLive(setup.spec)
          ? await TaskRunner.runLive(
              agentId,
              setup.spec,
              label: _processLabel(target),
              onSpontaneousTurn: (run) => _onSpontaneousTurn(agentId, run),
            )
          : await TaskRunner.run(setup.spec);
    } catch (error, stackTrace) {
      Log.e(
        'No se pudo preparar el turno de @${target.name}',
        error: error,
        stackTrace: stackTrace,
      );
      _appendMessage(
        agentId,
        ChatMessage(
          role: ChatRole.error,
          text: 'No se pudo arrancar el turno: $error',
          timestamp: DateTime.now(),
        ),
      );
      _setStreaming(agentId, false);
      _writes.schedule(agentId);
      return;
    }

    await _consumeTurn(
      agentId,
      target,
      run,
      isKeelAi: _isKeelAi(target.profileId),
    );
  }

  /// Starts [agentId]'s CLI process before its next message, so that message
  /// only waits for the model. Called when a chat is opened or selected, and
  /// after a setting that changes how the process starts.
  Future<void> warmUp(String agentId) async {
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null || target.isStreaming) return;
    try {
      final setup = await _prepareTurn(target, prompt: '');
      if (!TaskRunner.supportsLive(setup.spec)) return;
      await TaskRunner.warmLive(
        agentId,
        setup.spec,
        label: _processLabel(target),
        onSpontaneousTurn: (run) => _onSpontaneousTurn(agentId, run),
      );
    } catch (error) {
      // Warming is an optimization: the next message starts the process
      // itself and reports whatever goes wrong there.
      Log.w('No se pudo precalentar el chat con @${target.name}: $error');
    }
  }

  /// The spec [sendMessage] and [warmUp] launch for [agentId]'s next turn.
  @visibleForTesting
  Future<TaskRunSpec> nextTurnSpec(String agentId) async {
    final target = data.agents.firstWhere((agent) => agent.id == agentId);
    return (await _prepareTurn(target, prompt: '')).spec;
  }

  String _processLabel(Agent agent) => 'chat con @${agent.name}';

  /// The provider went back to work with nobody sending anything — a
  /// background task finished and re-invoked the model. That is work in
  /// progress like any other turn, so it shows as one.
  void _onSpontaneousTurn(String agentId, TaskRun run) {
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null) {
      run.cancel();
      return;
    }
    _setStreaming(agentId, true);
    unawaited(
      _consumeTurn(agentId, target, run, isKeelAi: _isKeelAi(target.profileId)),
    );
  }

  /// Everything a turn needs besides the user's words: the MCP servers, the
  /// hooks, the provider secret and the system prompt. Shared by [sendMessage]
  /// and [warmUp], so a warmed process starts exactly like the turn that will
  /// use it — otherwise it would not be reused.
  Future<({TaskRunSpec spec, List<String> hookNotes})> _prepareTurn(
    Agent target, {
    required String prompt,
  }) async {
    final workingDirectory = looseAgentWorkingDirectory;
    final isKeelAi = _isKeelAi(target.profileId);

    // Mismo motivo que en el turno de un proyecto: el mapa de las bases
    // sale del disco, y sin esperar la carga el agente arrancaría sin saber
    // que su base existe. La sección PROYECTOS CONOCIDOS del prompt lee dos
    // catálogos que este turno puede ser el primero en tocar. Las tres
    // esperas son independientes: van juntas.
    await Future.wait([
      KnowledgeService.instance.notifier.indexReady,
      ProjectsService.instance.notifier.ready,
      WorkspaceRootsService.instance.notifier.ready,
      SkillsService.instance.notifier.ready,
      RulesService.instance.notifier.ready,
      AgentProfilesService.instance.notifier.ready,
    ]);

    // One merged --mcp-config for the turn: the system-management tools
    // (Keel AI's reserved profile, plus any profile the user marked as a
    // builder) and whatever executable tools this agent's profile has
    // assigned.
    final keelAiEntry = isKeelAi || _canManageSystem(target.profileId)
        ? AssistantMcpServer.mcpServerEntryFor(target.id)
        : null;
    final profileTools = _resolveProfileTools(target.profileId);
    final contextItems = _profileContextItems(target.profileId);
    final context = ContextMcpServer.servesProvider(target.provider.alias)
        ? ContextMcpServer.register(contextItems)
        : null;
    final toolsEntry = profileTools.isEmpty
        ? null
        : UserToolsMcpServer.mcpServerEntryFor(
            target.profileId!,
            workingDirectory: workingDirectory,
          );
    // External MCP integrations (gmail, drive, …) the profile declares —
    // secret references resolve to values HERE, inside JSON that only ever
    // travels as a 0700 temp file (see ClaudeCliService).
    final externalServers = _resolveProfileMcpServers(target.profileId);
    final externalSecretValues = SecretsService.instance.notifier.valuesFor([
      for (final server in externalServers) ...server.secretNames,
    ]);

    final mcpServers = <String, dynamic>{
      'keelai-actions': ?keelAiEntry,
      kUserToolsMcpServerKey: ?toolsEntry,
      kContextMcpServerKey: ?context?.entry,
      for (final server in externalServers)
        server.name: server.toMcpServerEntry(externalSecretValues),
    };

    // Los guardarraíles del turno. Se resuelven ACÁ, con el catálogo y los
    // secrets a mano, y lo que llega al CLI son archivos ya escritos.
    final (turnHooks, providerApiKey) = await (
      _resolveTurnHooks(target),
      SecretsService.instance.notifier.resolveValue(target.provider.secretName),
    ).wait;

    final codex = SettingsService.instance.notifier.data.codex;
    final isCodex = target.provider == AgentProvider.codex;
    final gate = await _permissionGateFor(target);
    final runnerGate = target.provider == AgentProvider.openCode ? gate : null;
    // A hook-gated API turn offers the tools that write: each call stops at
    // the gate and asks. Without the gate they stay unoffered.
    final offersGatedWrites =
        gate != null &&
        (target.provider == AgentProvider.openRouter ||
            target.provider == AgentProvider.deepSeek ||
            target.provider == AgentProvider.liteRt);
    final effort = await ModelCatalogService.instance.notifier.effortFor(
      target.provider,
      target.model,
      target.effort,
    );
    return (
      spec: TaskRunSpec(
        prompt: prompt,
        workingDirectory: workingDirectory,
        model: target.model,
        fullFileSystemAccess:
            target.fullFileSystemAccess || (isCodex && codex.fullDiskAccess),
        sandboxNetworkAccess: isCodex && codex.networkAccess,
        permissionGateUrl: runnerGate?.url,
        permissionGateToken: runnerGate?.token,
        effort: effort,
        provider: target.provider.alias,
        providerApiKey: providerApiKey,
        sessionId: target.sessionId,
        additionalSystemPrompt: _resolveProfileSystemPrompt(
          target.profileId,
          contextItems,
          context?.manifest,
        ),
        extraAllowedTools: [
          ...SettingsService.instance.notifier.data.extraAllowedTools,
          if (offersGatedWrites) ...kDecisionGateTools,
          if (keelAiEntry != null) ...kKeelAiMcpToolNames,
          if (toolsEntry != null)
            ...profileTools.map(
              (tool) => '$kUserToolsMcpToolPrefix${tool.name}',
            ),
          if (context != null) ...kContextMcpToolNames,
          // Server-level grant: every tool an external MCP exposes.
          ...externalServers.map((server) => 'mcp__${server.name}'),
        ],
        mcpConfig: mcpServers.isEmpty
            ? null
            : jsonEncode({'mcpServers': mcpServers}),
        hooksSettings: turnHooks.claudeSettings,
        hooksConfig: turnHooks.codexConfig,
        hookFiles: turnHooks.files,
        conversationHistory: remoteConversationHistory(target.messages),
        planMode: target.planMode,
      ),
      hookNotes: turnHooks.notes,
    );
  }

  /// Reads one turn's events into the chat until the turn ends, then hands
  /// the chat back: usage, Keel AI's actions, the plan decision and whatever
  /// was queued meanwhile.
  Future<void> _consumeTurn(
    String agentId,
    Agent target,
    TaskRun run, {
    required bool isKeelAi,
  }) async {
    // El mismo colector que usa un proyecto: resuelve contra el directorio
    // del turno las rutas relativas que reporta la CLI.
    final fileEdits = FileEditCollector(
      workingDirectory: looseAgentWorkingDirectory,
    );
    final assistantTextBuffer = StringBuffer();
    _runningTurns[agentId] = run;

    var wasStopped = false;
    // Si el turno llegó a dejar su fila en el ledger, y si el proveedor
    // alcanzó a hablar. Los dos hacen falta para la fila sin medición del
    // `finally`: sin la primera se anotaría dos veces, y sin la segunda se
    // anotaría un turno que murió antes de gastar un solo token.
    var turnMeasured = false;
    var providerEngaged = false;
    final streamTimestamp = DateTime.now();
    // `finally`, porque un turno que revienta igual tiene que devolver el
    // chat. Sin esto, un error del stream dejaba `isStreaming` en true para
    // siempre: todo lo que escribieras después se encolaba en silencio y la
    // única salida era reiniciar. Es la misma razón que ya documenta
    // `_runMemberTurn` del lado de proyectos.
    try {
      await for (final event in run.events) {
        if (_stoppedRuns.remove(run)) {
          wasStopped = true;
          break;
        }
        switch (event) {
          // El proceso vive en el otro isolate; de acá solo se ve su pid, que
          // es lo único que la pantalla de Máquina necesita para decir de
          // parte de quién corre.
          case TaskProcessStarted(pid: final pid):
            _runningPids[agentId] = pid;
            RunningProcesses.register(pid, _processLabel(target));

          case TaskSessionStarted(sessionId: final sessionId):
            providerEngaged = true;
            _updateAgent(
              agentId,
              (agent) => agent.copyWith(sessionId: sessionId),
            );

          case TaskAssistantText(text: final chunk):
            providerEngaged = true;
            _setCurrentActivity(agentId, null);
            assistantTextBuffer.writeln(chunk);
            _appendStreamingAssistantMessage(
              agentId,
              ChatMessage(
                role: ChatRole.assistant,
                text: chunk,
                timestamp: streamTimestamp,
                reasoning: _consumeLiveReasoning(agentId),
                fileEdits: await fileEdits.collect(),
              ),
            );

          case TaskToolUse(name: final name, input: final input):
            _setCurrentActivity(
              agentId,
              AgentToolActivity.fromToolUse(name, input),
            );
            final filePath = FileEditCollector.filePathFor(name, input);
            if (filePath != null) await fileEdits.noteBeforeEdit(filePath);

          // El chat 1:1 no tiene mapa donde poner un subagente, pero sí puede
          // decir qué está haciendo: la tira pasa a hablar de ÉL en vez de
          // quedarse en «delegando» hasta que vuelva.
          case TaskSubagentStarted(agentType: final type, ask: final ask):
            _setCurrentActivity(
              agentId,
              AgentToolActivity(
                kind: AgentToolKind.task,
                label: ask.isEmpty ? type : '$type · $ask',
              ),
            );

          case TaskSubagentToolUse(name: final name, input: final input):
            _setCurrentActivity(
              agentId,
              AgentToolActivity.fromToolUse(name, input),
            );

          case TaskSubagentFinished():
            _setCurrentActivity(agentId, null);

          // Lo que un subagente escribe y piensa NO entra al mensaje del padre.
          // Mezclarlos era el error que la bandera vino a arreglar; acá todavía
          // no hay dónde mostrarlos firmados bien, así que no se muestran.
          case TaskSubagentText() || TaskSubagentReasoning():
            break;

          case TaskReasoningChunk(text: final chunk):
            _appendLiveReasoning(agentId, chunk);

          case TaskContextUsage(
            usedTokens: final usedTokens,
            contextWindowTokens: final contextWindowTokens,
          ):
            _updateAgent(
              agentId,
              (agent) => agent.copyWith(
                contextUsedTokens: usedTokens,
                contextWindowTokens: contextWindowTokens,
              ),
            );

          case TaskPermissionDenied(
            toolName: final toolName,
            message: final message,
          ):
            _setCurrentActivity(agentId, null);
            _updateAgent(
              agentId,
              (agent) => agent.copyWith(
                pendingPermission: PermissionRequest(
                  toolName: toolName,
                  message: message,
                ),
              ),
            );

          case final TaskTurnCompleted turn:
            turnMeasured = true;
            final costUsd = turn.costUsd;
            final durationMs = turn.durationMs;
            unawaited(
              UsageLedgerService.instance.notifier.record(
                provider: target.provider.alias,
                model: turn.model.isEmpty ? target.model : turn.model,
                profileId: target.profileId ?? '',
                sessionId: agentId,
                inputTokens: turn.inputTokens,
                outputTokens: turn.outputTokens,
                cacheReadTokens: turn.cacheReadTokens,
                cacheCreationTokens: turn.cacheCreationTokens,
                tokensReported: turn.tokensReported,
                durationMs: durationMs,
                costUsd: costUsd,
                costReported: turn.costReported,
                contextUsedTokens: turn.contextUsedTokens,
                contextWindowTokens: turn.contextWindowTokens,
              ),
            );
            if (turn.needsProviderFailureFallback) {
              _appendMessage(
                agentId,
                ChatMessage(
                  role: ChatRole.error,
                  text: target.provider.turnFailureMessage(),
                  timestamp: DateTime.now(),
                ),
              );
            } else {
              _annotateLastAssistantMessage(
                agentId,
                costUsd: costUsd,
                durationMs: durationMs,
              );
            }

          case TaskNotice(message: final message):
            appendTurnNotice(agentId, message);

          case TaskSteerDelivered(text: final text):
            _unconfirmedSteers[run]?.remove(text);

          case TaskFailure(message: final message):
            _appendMessage(
              agentId,
              ChatMessage(
                role: ChatRole.error,
                text: message,
                timestamp: DateTime.now(),
              ),
            );
        }
      }
    } finally {
      // Parar mata el proceso, así que lo más común es que el stream se
      // cierre SIN un evento más — y la marca de «detenido» solo se consumía
      // adentro del bucle, con el evento siguiente. Quedaba puesta, y se la
      // comía el TURNO SIGUIENTE: moría en su primer evento y el chat no
      // hacía nada, hasta que mandabas el mismo mensaje una segunda vez.
      // Se consume acá, donde el turno termina de verdad, tome el camino que
      // tome.
      if (_stoppedRuns.remove(run)) wasStopped = true;

      // Un turno PARADO o que revienta nunca llega al evento `result`, así
      // que no dejaba fila: los tokens ya se gastaron y para la app el turno
      // no existió. Se anota igual, sin medición —el mismo criterio con el
      // que ya se anota codex—, porque «12 turnos, sin medición» es un dato
      // y una ausencia no es nada.
      if (providerEngaged && !turnMeasured) {
        unawaited(
          UsageLedgerService.instance.notifier.record(
            provider: target.provider.alias,
            model: target.model,
            profileId: target.profileId ?? '',
            sessionId: agentId,
            inputTokens: 0,
            outputTokens: 0,
            cacheReadTokens: 0,
            cacheCreationTokens: 0,
            tokensReported: false,
            durationMs: DateTime.now()
                .difference(streamTimestamp)
                .inMilliseconds,
            costUsd: 0,
            costReported: false,
          ),
        );
      }

      // A stopped turn already handed the agent back in [stopAgent], and by
      // now the agent's next turn may be the one running.
      if (identical(_runningTurns[agentId], run)) {
        _runningTurns.remove(agentId);
        final finishedPid = _runningPids.remove(agentId);
        if (finishedPid != null) RunningProcesses.unregister(finishedPid);
        _setCurrentActivity(agentId, null);
        _updateAgent(
          agentId,
          (agent) => agent.copyWith(clearLiveReasoning: true),
        );
        _setStreaming(agentId, false);
      }
      _requeueUnconfirmedSteers(agentId, run, stopped: wasStopped);

      if (isKeelAi) {
        await _runAssistantActions(
          agentId,
          assistantText: assistantTextBuffer.toString(),
        );
      }

      // El turno terminó: esto sí se baja ya, sin esperar el debounce.
      await _writes.flush(agentId);

      // El turno planificó y llegó al final solo: hay algo que decidir.
      //
      // Se pide la decisión solo si NO hay nada encolado. Un mensaje escrito
      // mientras el agente planificaba ya es la decisión del usuario —siguió
      // por otro lado—, y levantar la tarjeta ahí la dejaría flotando sobre un
      // agente que en un instante arranca otro turno.
      final planned = shouldAskToImplement(
        planMode: target.planMode,
        stopped: wasStopped,
        hasAnswer: assistantTextBuffer.toString().trim().isNotEmpty,
        hasQueuedMessages:
            data.agents
                .where((agent) => agent.id == agentId)
                .firstOrNull
                ?.queuedMessages
                .isNotEmpty ??
            false,
      );
      if (planned) {
        _updateAgent(
          agentId,
          (agent) => agent.copyWith(planAwaitingDecision: true),
        );
      }

      // Whatever the user typed during the turn goes out now — unless they
      // STOPPED the agent, which is a deliberate "take control": firing a new
      // turn right after would be the opposite of what the stop button means.
      // Those messages stay queued with an explicit "Enviar ahora".
      if (!wasStopped) unawaited(sendQueuedMessages(agentId));
    }
  }

  /// Sends everything queued during the last turn as ONE next turn: the
  /// order is preserved and the model reads them together, which is what
  /// "I sent a correction while you were working" means. No-op while the
  /// agent is busy — the next turn's own ending will pick them up.
  Future<void> sendQueuedMessages(String agentId) async {
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null || target.isStreaming) return;
    final queued = target.queuedMessages;
    if (queued.isEmpty) return;

    _updateAgent(agentId, (agent) => agent.copyWith(queuedMessages: const []));
    await sendMessage(
      agentId,
      queued
          .map((message) => message.text)
          .where((text) => text.isNotEmpty)
          .join('\n\n'),
      imagePaths: [for (final message in queued) ...message.imagePaths],
    );
  }

  /// Reescribe un mensaje que todavía no salió.
  ///
  /// Se direcciona por id y no por índice: mientras la tarjeta está abierta
  /// puede terminar un turno y sacar mensajes de la cola, y editar «el
  /// segundo» sería editar otro.
  void editQueuedMessage(String agentId, String messageId, String text) {
    final trimmed = text.trim();
    _replaceQueuedMessage(
      agentId,
      messageId,
      (message) => trimmed.isEmpty && message.imagePaths.isEmpty
          ? message
          : message.copyWith(text: trimmed),
    );
  }

  /// Lo devuelve a la espera: sale cuando vos digas.
  void holdQueuedMessage(String agentId, String messageId) {
    _setQueuedDelivery(agentId, messageId, QueuedDelivery.standby);
  }

  /// Que salga solo apenas el turno en curso entregue el control.
  Future<void> sendQueuedMessageAfterTurn(
    String agentId,
    String messageId,
  ) async {
    _setQueuedDelivery(agentId, messageId, QueuedDelivery.afterCurrentTurn);
    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (!(target?.isStreaming ?? false)) await sendQueuedMessages(agentId);
  }

  /// Lets this message out now. A turn in flight that takes messages gets
  /// it at its next tool boundary and goes on, as in the session chat. One
  /// that cannot is stopped, and the message goes out as the next turn.
  Future<void> sendQueuedMessageNow(String agentId, String messageId) async {
    if (await _steerQueuedMessage(agentId, messageId)) return;
    _setQueuedDelivery(agentId, messageId, QueuedDelivery.interrupting);

    final target = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull;
    if (target == null) return;
    if (target.isStreaming) {
      stopAgent(agentId);
      // `stopAgent` no dispara la cola —parar es tomar el control—, así que
      // el envío lo pide explícitamente quien lo interrumpió.
      await sendQueuedMessages(agentId);
      return;
    }
    await sendQueuedMessages(agentId);
  }

  /// Hands a queued message to the turn in flight without stopping it: the
  /// agent reads it at its next tool boundary and the turn goes on. False
  /// when the turn cannot take it.
  Future<bool> _steerQueuedMessage(String agentId, String messageId) async {
    final run = _runningTurns[agentId];
    final message = data.agents
        .where((agent) => agent.id == agentId)
        .firstOrNull
        ?.queuedMessages
        .where((queued) => queued.id == messageId)
        .firstOrNull;
    if (run == null || !run.canSteer || message == null) return false;
    final prompt = await _promptForModel(message.text, message.imagePaths);
    // Resolving references waits: the turn may have ended meanwhile.
    if (!identical(_runningTurns[agentId], run) || !run.steer(prompt)) {
      return false;
    }
    (_unconfirmedSteers[run] ??= {})[prompt] = message;
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        queuedMessages: [
          for (final queued in agent.queuedMessages)
            if (queued.id != messageId) queued,
        ],
      ),
    );
    _appendMessage(
      agentId,
      ChatMessage(
        role: ChatRole.user,
        text: message.text,
        timestamp: DateTime.now(),
        imagePaths: message.imagePaths,
      ),
    );
    appendSystemNote(
      agentId,
      'Entregado en su próximo paso, sin cortar el turno.',
    );
    _writes.schedule(agentId);
    return true;
  }

  /// What was handed to a turn and never entered —the turn ended first, or
  /// it was stopped— goes back to the queue. After a stop it waits there:
  /// stopping is taking control, not asking for it to go out on its own.
  void _requeueUnconfirmedSteers(
    String agentId,
    TaskRun run, {
    required bool stopped,
  }) {
    final missed = _unconfirmedSteers.remove(run);
    if (missed == null || missed.isEmpty) return;
    final delivery = stopped
        ? QueuedDelivery.standby
        : QueuedDelivery.afterCurrentTurn;
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        queuedMessages: [
          ...agent.queuedMessages,
          for (final message in missed.values)
            message.copyWith(delivery: delivery),
        ],
      ),
    );
    appendSystemNote(
      agentId,
      missed.length == 1
          ? 'El turno terminó antes de que el agente leyera tu mensaje: '
                'volvió a la cola.'
          : 'El turno terminó antes de que el agente leyera '
                '${missed.length} mensajes: volvieron a la cola.',
    );
  }

  void _replaceQueuedMessage(
    String agentId,
    String messageId,
    QueuedMessage Function(QueuedMessage) change,
  ) {
    _updateAgent(agentId, (agent) {
      return agent.copyWith(
        queuedMessages: [
          for (final message in agent.queuedMessages)
            if (message.id == messageId) change(message) else message,
        ],
      );
    });
  }

  void _setQueuedDelivery(
    String agentId,
    String messageId,
    QueuedDelivery delivery,
  ) {
    _replaceQueuedMessage(
      agentId,
      messageId,
      (message) => message.copyWith(delivery: delivery),
    );
  }

  /// Saca un mensaje de la cola antes de que salga — cambiaste de idea
  /// sobre la corrección que escribiste a mitad de turno.
  void removeQueuedMessage(String agentId, String messageId) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        queuedMessages: [
          for (final message in agent.queuedMessages)
            if (message.id != messageId) message,
        ],
      ),
    );
  }

  /// Appends a system-authored trace line to [agentId]'s thread. Used by
  /// live MCP tool handlers so a create/update action is visible in the
  /// thread the moment it happens, not summarized after the turn ends.
  void appendSystemNote(String agentId, String text) {
    _appendMessage(
      agentId,
      ChatMessage(role: ChatRole.system, text: text, timestamp: DateTime.now()),
    );
  }

  /// Turn setup can report the same unavailable integration or context
  /// reduction on every send. Keep one visible notice in this conversation.
  void appendTurnNotice(String agentId, String text) {
    final agent = data.agents.where((agent) => agent.id == agentId).firstOrNull;
    if (agent == null ||
        agent.messages.any(
          (message) => message.role == ChatRole.system && message.text == text,
        )) {
      return;
    }
    appendSystemNote(agentId, text);
  }

  /// The executable tools [profileId] has assigned, resolved against the
  /// live catalog. Empty for agents without a profile — tools are granted
  /// by profile assignment only, never ambient.
  List<Tool> _resolveProfileTools(String? profileId) {
    if (profileId == null) return const [];
    final profile = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.id == profileId)
        .firstOrNull;
    if (profile == null) return const [];
    return ToolsService.instance.notifier.toolsByNames(profile.tools);
  }

  /// External MCP servers [profileId] declares, resolved against the live
  /// catalog. Empty without a profile — integrations are granted per
  /// profile, never ambient.
  List<McpServerConfig> _resolveProfileMcpServers(String? profileId) {
    if (profileId == null) return const [];
    final profile = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.id == profileId)
        .firstOrNull;
    if (profile == null) return const [];
    return McpServersService.instance.notifier.serversByNames(
      profile.mcpServers,
    );
  }

  /// The agents that belong in a user-facing list. Keel AI's own sessions
  /// are excluded: the assistant lives in its dedicated window, and mixing
  /// its sessions in with the agents the user registered is exactly the
  /// confusion that window exists to avoid.
  List<Agent> get listableAgents =>
      data.agents.where((agent) => !_isKeelAi(agent.profileId)).toList();

  bool _isKeelAi(String? profileId) {
    if (profileId == null) return false;
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    return profiles
            .where((profile) => profile.id == profileId)
            .firstOrNull
            ?.name ==
        kKeelAiHandle;
  }

  /// Builder profiles get the same creation MCP as Keel AI — an explicit
  /// per-profile grant, resolved live so revoking it takes effect on the
  /// very next turn.
  bool _canManageSystem(String? profileId) {
    if (profileId == null) return false;
    return AgentProfilesService.instance.notifier.data.profiles
            .where((profile) => profile.id == profileId)
            .firstOrNull
            ?.canManageSystem ??
        false;
  }

  /// Reads whatever Keel AI wrote this turn for action blocks and runs them.
  /// Scoped to the reserved profile only — an ordinary agent's reply is
  /// never scanned, even if its text happens to contain something shaped
  /// like a block. A reply with no blocks is left alone: no automatic
  /// follow-up, the user decides whether to insist.
  Future<void> _runAssistantActions(
    String agentId, {
    required String assistantText,
  }) async {
    final l10n =
        SettingsService.instance.notifier.data.language.startsWith('es')
        ? AppLocalizationsEs()
        : AppLocalizationsEn();
    final actions = parseAssistantActions(assistantText);
    if (actions.isEmpty) return;

    // Legacy fenced action blocks cannot declare intent/reason or pause for
    // the approval UI. Refuse the whole batch if it includes a locked target
    // rather than allowing this older transport to bypass the MCP guard.
    final locked = actions
        .map(_lockedLegacyActionName)
        .whereType<String>()
        .toList();
    if (locked.isNotEmpty) {
      _appendMessage(
        agentId,
        ChatMessage(
          role: ChatRole.assistant,
          text: l10n.assistantLegacyBlocked(locked.join(', ')),
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final results = executeAssistantActions(actions, l10n: l10n);
    final summary = summarizeAssistantActionResults(results);
    if (summary.isEmpty) return;

    _appendMessage(
      agentId,
      ChatMessage(
        role: ChatRole.assistant,
        text: summary,
        timestamp: DateTime.now(),
      ),
    );
  }

  String? _lockedLegacyActionName(AssistantAction action) {
    final target = switch (action) {
      CreateSkillAction(:final name) => (CatalogLockKind.skill, name),
      CreateRuleAction(:final name) => (CatalogLockKind.rule, name),
      CreateToolAction(:final name) => (CatalogLockKind.tool, name),
      CreateAgentAction(:final handle) => (CatalogLockKind.agent, handle),
      CreateWorkflowAction(:final name) => (CatalogLockKind.workflow, name),
      CreateProjectAction(:final name) => (CatalogLockKind.project, name),
    };
    return CatalogLocksService.instance.notifier.isLocked(target.$1, target.$2)
        ? '${target.$1.alias}:${target.$2}'
        : null;
  }

  /// Concatenates the GLOBAL skills (every agent gets them, profile or
  /// not), then [profileId]'s own `systemPrompt`, assigned skills, and
  /// rules, for injection into the agent's system prompt. Selection is
  /// static — decided when the profile/skill was configured, never inferred
  /// by the model at runtime.
  /// Los hooks que corren en el turno de [agent].
  ///
  /// En 1:1 no hay proyecto, así que solo cuentan los globales y los del
  /// perfil. Keel AI queda afuera de todo esto —lo decide `resolveHooks`—
  /// porque es a quien se le pide apagar un hook que trabó al resto.
  Future<TurnHooks> _resolveTurnHooks(Agent agent) async {
    // OpenCode runs no shell hooks (only JS plugins, which Keel starts it
    // without): its permission requests reach the gate through the runner.
    if (agent.provider == AgentProvider.openCode) return TurnHooks.none;
    await HooksService.instance.notifier.ready;
    final catalog = HooksService.instance.notifier.data.hooks;
    final gate = await _permissionGateFor(agent);
    // Claude opens subagents with its own tool, with no cap of its own: the
    // guard keeps at most `SubagentLimits.maxParallel` running at once.
    final isClaude = agent.provider == AgentProvider.claude;
    if (catalog.isEmpty && gate == null && !isClaude) return TurnHooks.none;

    final profile = agent.profileId == null
        ? null
        : AgentProfilesService.instance.notifier.data.profiles
              .where((entry) => entry.id == agent.profileId)
              .firstOrNull;

    final tools = ToolsService.instance.notifier.data.tools;
    return prepareTurnHooks(
      catalog: catalog,
      tools: tools,
      secretValues: SecretsService.instance.notifier.valuesFor(
        hookSecretNames(catalog, tools),
      ),
      provider: agent.provider == AgentProvider.codex
          ? HookProvider.codex
          : HookProvider.claude,
      profile: profile,
      gate: gate,
      parallelSubagentCap: isClaude ? SubagentLimits.maxParallel : null,
    );
  }

  /// Keel's permission gate for this chat's turns, or null when the provider
  /// asks on its own. Claude keeps its allowed-tools flow; codex runs with
  /// `approval_policy=never`, so without the gate nothing would ever ask
  /// before it writes or runs a command.
  Future<DecisionGateSpec?> _permissionGateFor(Agent agent) async {
    final usesGate = switch (agent.provider) {
      AgentProvider.claude => false,
      AgentProvider.codex =>
        SettingsService.instance.notifier.data.codex.askPermission,
      // OpenCode asks on its own (`permission.asked`); the gate answers it.
      AgentProvider.openCode => true,
      // API providers run Keel's own tools: with the gate, writing and
      // running commands are offered and asked for, not hidden.
      AgentProvider.openRouter ||
      AgentProvider.deepSeek ||
      AgentProvider.liteRt => true,
    };
    if (!usesGate) return null;
    await DecisionGateServer.ensureStarted();
    return DecisionGateServer.agentGateSpecFor(agent.id);
  }

  static const _knowledgeContextKind = 'knowledge';

  List<TurnContextItem> _profileContextItems(String? profileId) {
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    final profile = profileId == null
        ? null
        : profiles.where((entry) => entry.id == profileId).firstOrNull;
    final skills = SkillsService.instance.notifier.data.skills;
    final rules = RulesService.instance.notifier.data.rules;
    final items = <TurnContextItem>[
      for (final skill in skills)
        if (skill.isGlobal && skill.content.trim().isNotEmpty)
          TurnContextItem(
            id: 'skill:${skill.id}',
            kind: 'skill',
            name: skill.name,
            content: skill.content,
            required: true,
          ),
    ];
    if (profile != null) {
      if (profile.systemPrompt.trim().isNotEmpty) {
        items.add(
          TurnContextItem(
            id: 'profile:${profile.id}',
            kind: 'profile',
            name: profile.name,
            content: profile.systemPrompt,
            required: true,
          ),
        );
      }
      for (final skillName in profile.skills) {
        final skill = skills
            .where((entry) => entry.name == skillName)
            .firstOrNull;
        if (skill == null || skill.content.isEmpty || skill.isGlobal) continue;
        items.add(
          TurnContextItem(
            id: 'skill:${skill.id}',
            kind: 'skill',
            name: skill.name,
            content: skill.content,
          ),
        );
      }
      for (final ruleName in profile.rules) {
        final rule = rules.where((entry) => entry.name == ruleName).firstOrNull;
        if (rule == null || rule.content.isEmpty) continue;
        items.add(
          TurnContextItem(
            id: 'rule:${rule.id}',
            kind: 'rule',
            name: rule.name,
            content: rule.content,
            required: true,
          ),
        );
      }
      final rootsSection = _knownRootsSection();
      if (rootsSection.isNotEmpty) {
        items.add(
          TurnContextItem(
            id: 'workspace:roots',
            kind: 'workspace',
            name: 'Rutas conocidas',
            content: rootsSection,
          ),
        );
      }
      final knowledge = KnowledgeService.instance.notifier.briefFor(
        profile.knowledgeBaseNames,
      );
      if (knowledge.trim().isNotEmpty) {
        items.add(
          TurnContextItem(
            id: 'knowledge:brief',
            kind: _knowledgeContextKind,
            name: 'Bases de saber',
            content: knowledge,
          ),
        );
      }
    }
    return items;
  }

  /// The system prompt of a 1:1 turn. With [manifest] the model reads
  /// [context] on demand; without it, [context] goes inline.
  String? _resolveProfileSystemPrompt(
    String? profileId,
    List<TurnContextItem> context,
    String? manifest,
  ) {
    final profile = profileId == null
        ? null
        : AgentProfilesService.instance.notifier.data.profiles
              .where((entry) => entry.id == profileId)
              .firstOrNull;
    final usesGithubMcp =
        profile != null &&
        _resolveProfileMcpServers(profile.id).any(isGithubMcpServer);
    if (manifest == null) {
      // Knowledge goes last, after everything stable: its text carries each
      // base's document count, so it changes whenever an agent writes one,
      // and whatever came after it would fall out of the cached prefix.
      final combined = composeTurnSystemPrompt(
        stablePrompt: [
          for (final item in context)
            if (item.kind != _knowledgeContextKind) item.content,
          if (usesGithubMcp) kGithubMcpPrompt,
        ].join('\n\n'),
        knowledge: [
          for (final item in context)
            if (item.kind == _knowledgeContextKind) item.content,
        ].join('\n\n'),
      );
      return combined.isEmpty ? null : combined;
    }
    return [
      if (profile != null) 'Eres @${profile.name}. Función: ${profile.role}.',
      if (profile?.name == kKeelAiHandle) '[KEEL_AI_PROFILE]',
      kOnDemandContextInstructions,
      'CONTEXT_MANIFEST_JSON: $manifest',
      if (usesGithubMcp) kGithubMcpPrompt,
    ].join('\n\n');
  }

  /// Las rutas reales de esta máquina, para el prompt de un agente sin
  /// proyecto: los proyectos registrados y las demás carpetas conocidas.
  String _knownRootsSection() {
    final projects = ProjectsService.instance.notifier.data.projects;
    final registered = [
      for (final project in projects)
        if (project.workingDirectory.trim().isNotEmpty)
          (name: project.name, path: project.workingDirectory.trim()),
    ];
    final taken = {for (final project in registered) project.path};
    final others = [
      for (final root in WorkspaceRootsService.instance.notifier.recentPaths)
        if (!taken.contains(root)) root,
    ];
    return knownRootsPrompt(projects: registered, otherRoots: others);
  }

  /// How attached images reach the model: as PATHS it reads on demand with
  /// its own Read tool, never as bytes we inline into the prompt. A 4 MB
  /// screenshot costs nothing until the agent decides it needs to look, and
  /// the path stays valid because the file lives in app storage.
  /// What the model reads for [text]. The `keel://` references the composer
  /// left in it are materialized here, for this turn only: a linked skill
  /// brings its content, a folder its absolute path. The thread keeps showing
  /// the name the user picked.
  Future<String> _promptForModel(
    String text,
    List<String> imagePaths, {
    FileEdit? pendingUserEdit,
  }) async {
    await Future.wait([
      ProjectsService.instance.notifier.ready,
      WorkspaceRootsService.instance.notifier.ready,
    ]);
    final explicitContext = await ChatReferenceService.promptContext(
      const GlobalReferenceScope(),
      text,
    );
    return [
      if (pendingUserEdit != null) _describeManualEdit(pendingUserEdit),
      if (text.isNotEmpty) text,
      if (explicitContext.isNotEmpty) explicitContext,
      if (imagePaths.isNotEmpty) _describeAttachments(imagePaths),
    ].join('\n\n');
  }

  String _describeAttachments(List<String> imagePaths) {
    final buffer = StringBuffer()
      ..writeln(
        'El usuario adjuntó ${imagePaths.length == 1 ? 'una imagen' : '${imagePaths.length} imágenes'} '
        'a este mensaje. Leelas con la tool Read antes de responder:',
      );
    for (final path in imagePaths) {
      buffer.writeln('- $path');
    }
    return buffer.toString().trim();
  }

  String _describeManualEdit(FileEdit edit) {
    final fileName = edit.path.split('/').last;
    final diff = computeLineDiff(edit.beforeContent ?? '', edit.afterContent);
    if (diff == null) {
      return 'Nota: el usuario acaba de editar manualmente el archivo '
          '$fileName (${edit.path}); es muy grande para incluir el diff aquí.';
    }

    final changed = diff
        .where((line) => line.type != LineDiffType.unchanged)
        .take(200);

    final buffer = StringBuffer()
      ..writeln(
        'Nota: el usuario acaba de editar manualmente el archivo $fileName '
        '(${edit.path}). Esto es lo que cambió:',
      )
      ..writeln('```diff');
    for (final line in changed) {
      final marker = switch (line.type) {
        LineDiffType.added => '+',
        LineDiffType.removed => '-',
        LineDiffType.unchanged => ' ',
      };
      buffer.writeln('$marker ${line.content}');
    }
    buffer.writeln('```');
    return buffer.toString();
  }

  void _setCurrentActivity(String agentId, AgentToolActivity? activity) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(
        currentActivity: activity,
        clearCurrentActivity: activity == null,
      ),
    );
  }

  void _appendLiveReasoning(String agentId, String chunk) {
    _updateAgent(
      agentId,
      (agent) =>
          agent.copyWith(liveReasoning: (agent.liveReasoning ?? '') + chunk),
    );
  }

  String? _consumeLiveReasoning(String agentId) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    final reasoning = index == -1 ? null : data.agents[index].liveReasoning;
    _updateAgent(agentId, (agent) => agent.copyWith(clearLiveReasoning: true));
    return (reasoning == null || reasoning.isEmpty) ? null : reasoning;
  }

  void _annotateLastAssistantMessage(
    String agentId, {
    required double costUsd,
    required int durationMs,
  }) {
    _updateAgent(agentId, (agent) {
      if (agent.messages.isEmpty) return agent;
      final lastIndex = agent.messages.length - 1;
      final last = agent.messages[lastIndex];
      if (last.role != ChatRole.assistant) return agent;

      // `copyWith`, no reconstruir: rearmarlo desde `text` + `fileEdits`
      // aplanaba la secuencia de bloques justo al cerrar el turno.
      final annotated = last.copyWith(costUsd: costUsd, durationMs: durationMs);
      final messages = [...agent.messages];
      messages[lastIndex] = annotated;
      return agent.copyWith(messages: messages);
    });
  }

  void _appendMessage(String agentId, ChatMessage message) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(messages: [...agent.messages, message]),
    );
  }

  /// A streamed answer is one message whose contents grow, never one bubble
  /// per token chunk. Besides preserving the transcript this keeps a reader
  /// anchored on the code they are inspecting instead of rebuilding the list.
  ///
  /// Grow means APPEND. `fileEdits: chunk.fileEdits` used to overwrite: the
  /// collector drains on every read, so the chunk after an edit carried an
  /// empty list and wiped the editor card the user was about to review.
  void _appendStreamingAssistantMessage(String agentId, ChatMessage chunk) {
    _updateAgent(agentId, (agent) {
      final messages = [...agent.messages];
      final index = messages.lastIndexWhere(
        (message) =>
            message.role == ChatRole.assistant &&
            message.timestamp == chunk.timestamp,
      );
      if (index == -1) {
        messages.add(chunk);
      } else {
        messages[index] = messages[index].appendingChunk(
          text: chunk.text,
          fileEdits: chunk.fileEdits,
          reasoning: chunk.reasoning,
        );
      }
      return agent.copyWith(messages: messages);
    });
  }

  void _setStreaming(String agentId, bool isStreaming) {
    _updateAgent(agentId, (agent) => agent.copyWith(isStreaming: isStreaming));
  }

  void _updateAgent(String agentId, Agent Function(Agent agent) transform) {
    final agents = data.agents
        .map((agent) => agent.id == agentId ? transform(agent) : agent)
        .toList();
    updateState(data.copyWith(agents: agents));
  }

  /// Reescribe la lista completa. Queda para lo que de verdad la necesita:
  /// borrar un agente, que además tiene que sacar su clave de la base.
  Future<void> _persist() {
    _writes.cancelPending();
    return _repository.save(data.agents);
  }
}

mixin AgentsService {
  static final ReactiveNotifier<AgentsViewModel> instance =
      ReactiveNotifier<AgentsViewModel>(() => AgentsViewModel());
}
