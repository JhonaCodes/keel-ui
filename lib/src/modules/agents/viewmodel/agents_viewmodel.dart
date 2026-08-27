import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';
import 'package:keel_ui/src/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_ui/src/integrations/machine/machine.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/service/remote_conversation_history.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/line_diff.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/model/plan_decision.dart';
import 'package:keel_ui/src/modules/agents/model/queued_message.dart';
import 'package:keel_ui/src/modules/agents/repository/agents_repository.dart';
import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/integrations/workspace_roots/workspace_roots.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_executor.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_parser.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

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
  final Set<String> _stoppedAgentIds = {};

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
      iconColor: suggestNextIconColor(),
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
  }

  void setAgentModel(String agentId, String model) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].model == model) return;

    _updateAgent(agentId, (agent) => agent.copyWith(model: model));
    _writes.schedule(agentId);
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
  }

  void setAgentEffort(String agentId, String effort) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].effort == effort) return;

    _updateAgent(agentId, (agent) => agent.copyWith(effort: effort));
    _writes.schedule(agentId);
  }

  void setAgentFullFileSystemAccess(String agentId, bool enabled) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(fullFileSystemAccess: enabled),
    );
    _writes.schedule(agentId);
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

  void respondToPermissionRequest(String agentId, {required bool grant}) {
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
  }

  void deleteAgent(String id) {
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

    _stoppedAgentIds.add(agentId);
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
    // Mid-turn: the CLIs are one-shot per turn, so there is nothing to
    // inject into. The message waits and goes out as the next turn instead
    // of the composer refusing to accept it.
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
    // Las referencias `keel://` que el compositor dejó en el texto se
    // materializan ACÁ, en el mismo turno y solo para él: una skill enlazada
    // aporta su contenido, una carpeta su ruta absoluta. Lo que el usuario
    // ve en el hilo sigue siendo el nombre que eligió.
    await Future.wait([
      ProjectsService.instance.notifier.ready,
      WorkspaceRootsService.instance.notifier.ready,
    ]);
    final explicitContext = await ChatReferenceService.promptContext(
      const GlobalReferenceScope(),
      trimmed,
    );

    final promptForModel = [
      if (pendingUserEdit != null) _describeManualEdit(pendingUserEdit),
      if (trimmed.isNotEmpty) trimmed,
      if (explicitContext.isNotEmpty) explicitContext,
      if (imagePaths.isNotEmpty) _describeAttachments(imagePaths),
    ].join('\n\n');

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

    final workingDirectory = looseAgentWorkingDirectory;
    // El mismo colector que usa un proyecto: resuelve contra el directorio
    // del turno las rutas relativas que reporta la CLI.
    final fileEdits = FileEditCollector(workingDirectory: workingDirectory);
    final assistantTextBuffer = StringBuffer();
    final isKeelAi = _isKeelAi(target.profileId);

    // One merged --mcp-config for the turn: the system-management tools
    // (Keel AI's reserved profile, plus any profile the user marked as a
    // builder) and whatever executable tools this agent's profile has
    // assigned.
    // Mismo motivo que en el turno de un proyecto: el mapa de las bases
    // sale del disco, y sin esperar la carga el agente arrancaría sin saber
    // que su base existe.
    // El MAPA de las bases, no solo el catálogo: sin índice el agente no
    // ve qué hay adentro de sus bases de saber. Es el único lugar donde
    // vale la pena esperar el recorrido del disco.
    await KnowledgeService.instance.notifier.indexReady;

    final keelAiEntry = isKeelAi || _canManageSystem(target.profileId)
        ? AssistantMcpServer.mcpServerEntryFor(agentId)
        : null;
    final profileTools = _resolveProfileTools(target.profileId);
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
      for (final server in externalServers)
        server.name: server.toMcpServerEntry(externalSecretValues),
    };
    final mcpConfig = mcpServers.isEmpty
        ? null
        : jsonEncode({'mcpServers': mcpServers});

    // The codex adapter has no tools/MCP/effort surface — see F6 doc.
    // La sección PROYECTOS CONOCIDOS del prompt lee dos catálogos que este
    // turno puede ser el primero en tocar. Sin esperarlos, el agente sale
    // creyendo que el usuario no tiene ningún proyecto — que es exactamente
    // el problema que esa sección viene a resolver.
    await Future.wait([
      ProjectsService.instance.notifier.ready,
      WorkspaceRootsService.instance.notifier.ready,
    ]);

    // Los guardarraíles del turno. Se resuelven ACÁ, con el catálogo y los
    // secrets a mano, y lo que llega al CLI son archivos ya escritos.
    final turnHooks = await _resolveTurnHooks(target);
    for (final note in turnHooks.notes) {
      appendSystemNote(agentId, note);
    }
    final providerApiKey = await SecretsService.instance.notifier.resolveValue(
      target.provider.secretName,
    );

    // UN solo camino para correr un turno, y corre en otro isolate.
    //
    // Antes esto tenía dos: `ClaudeCliService` y `CodexCliService`, ambos en
    // el hilo de la interfaz, decodificando cada línea del stream —incluidos
    // resultados de herramienta de cientos de KB— entre frame y frame. Los
    // proyectos ya usaban el task runner; el chat 1:1 y Keel AI se habían
    // quedado atrás, que es por qué la app se ponía pastosa justo mientras
    // se conversaba con el asistente.
    final run = await TaskRunner.run(
      TaskRunSpec(
        prompt: promptForModel,
        workingDirectory: workingDirectory,
        model: target.model,
        fullFileSystemAccess: target.fullFileSystemAccess,
        effort: target.effort,
        provider: target.provider.alias,
        providerApiKey: providerApiKey,
        sessionId: target.sessionId,
        additionalSystemPrompt: _resolveProfileSystemPrompt(target.profileId),
        extraAllowedTools: [
          ...SettingsService.instance.notifier.data.extraAllowedTools,
          if (keelAiEntry != null) ...kKeelAiMcpToolNames,
          if (toolsEntry != null)
            ...profileTools.map(
              (tool) => '$kUserToolsMcpToolPrefix${tool.name}',
            ),
          // Server-level grant: every tool an external MCP exposes.
          ...externalServers.map((server) => 'mcp__${server.name}'),
        ],
        mcpConfig: mcpConfig,
        hooksSettings: turnHooks.claudeSettings,
        hooksConfig: turnHooks.codexConfig,
        hookFiles: turnHooks.files,
        conversationHistory: remoteConversationHistory(target.messages),
        planMode: target.planMode,
      ),
    );
    _runningTurns[agentId] = run;

    var wasStopped = false;
    final streamTimestamp = DateTime.now();
    // `finally`, porque un turno que revienta igual tiene que devolver el
    // chat. Sin esto, un error del stream dejaba `isStreaming` en true para
    // siempre: todo lo que escribieras después se encolaba en silencio y la
    // única salida era reiniciar. Es la misma razón que ya documenta
    // `_runMemberTurn` del lado de proyectos.
    try {
      await for (final event in run.events) {
        if (_stoppedAgentIds.remove(agentId)) {
          wasStopped = true;
          break;
        }
        switch (event) {
          // El proceso vive en el otro isolate; de acá solo se ve su pid, que
          // es lo único que la pantalla de Máquina necesita para decir de
          // parte de quién corre.
          case TaskProcessStarted(pid: final pid):
            _runningPids[agentId] = pid;
            RunningProcesses.register(pid, 'chat con @${target.name}');

          case TaskSessionStarted(sessionId: final sessionId):
            _updateAgent(
              agentId,
              (agent) => agent.copyWith(sessionId: sessionId),
            );

          case TaskAssistantText(text: final chunk):
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
            _appendMessage(
              agentId,
              ChatMessage(
                role: ChatRole.system,
                text: message,
                timestamp: DateTime.now(),
              ),
            );

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
      if (_stoppedAgentIds.remove(agentId)) wasStopped = true;

      _runningTurns.remove(agentId);
      final finishedPid = _runningPids.remove(agentId);
      if (finishedPid != null) RunningProcesses.unregister(finishedPid);
      _setCurrentActivity(agentId, null);
      _updateAgent(
        agentId,
        (agent) => agent.copyWith(clearLiveReasoning: true),
      );
      _setStreaming(agentId, false);

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

  /// Interrumpe el turno en curso para que este mensaje salga ya.
  ///
  /// Parar es asíncrono: el turno detenido cierra su propio final y ahí
  /// despacha lo que quedó en cola. Si lo mandáramos también desde acá,
  /// saldrían dos turnos por el mismo mensaje.
  Future<void> sendQueuedMessageNow(String agentId, String messageId) async {
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
          text:
              'No ejecuté el bloque automático: intenta cambiar elementos '
              'bloqueados (${locked.join(', ')}). Usá las tools MCP con '
              'change_intent y change_reason para pedir permiso.',
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final results = executeAssistantActions(actions);
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
    await HooksService.instance.notifier.ready;
    final catalog = HooksService.instance.notifier.data.hooks;
    if (catalog.isEmpty) return TurnHooks.none;

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
    );
  }

  String? _resolveProfileSystemPrompt(String? profileId) {
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    final profile = profileId == null
        ? null
        : profiles.where((entry) => entry.id == profileId).firstOrNull;

    final skills = SkillsService.instance.notifier.data.skills;
    final rules = RulesService.instance.notifier.data.rules;
    final buffer = StringBuffer();

    for (final skill in skills) {
      if (!skill.isGlobal || skill.content.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(skill.content);
    }

    if (profile != null) {
      if (profile.systemPrompt.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(profile.systemPrompt);
      }
      for (final skillName in profile.skills) {
        final skill = skills
            .where((entry) => entry.name == skillName)
            .firstOrNull;
        // Globals already went in above — never inject the same skill twice.
        if (skill == null || skill.content.isEmpty || skill.isGlobal) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(skill.content);
      }
      for (final ruleName in profile.rules) {
        final rule = rules.where((entry) => entry.name == ruleName).firstOrNull;
        if (rule == null || rule.content.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(rule.content);
      }

      // El caso oráculo: en 1:1 no hay proyecto que aporte bases, así que
      // las únicas que llegan son las del propio perfil.
      final saber = KnowledgeService.instance.notifier.briefFor(
        profile.knowledgeBaseNames,
      );
      if (saber.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(saber);
      }

      // Dónde están los proyectos, con ruta absoluta. Un agente 1:1 corre
      // en `$HOME` y sin esto no tiene forma de saber que el proyecto del
      // usuario vive en otro disco.
      final rootsSection = _knownRootsSection();
      if (rootsSection.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(rootsSection);
      }

      // Misma regla que en un proyecto: teniendo el MCP de GitHub asignado,
      // GitHub se toca por ahí y no por `gh`. Acá no hay sección de ENTREGA
      // que corregir — un chat 1:1 no entrega pull requests.
      final usesGithubMcp = _resolveProfileMcpServers(
        profile.id,
      ).any(isGithubMcpServer);
      if (usesGithubMcp) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(kGithubMcpPrompt);
      }
    }

    final combined = buffer.toString().trim();
    return combined.isEmpty ? null : combined;
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

      final annotated = ChatMessage(
        role: last.role,
        text: last.text,
        timestamp: last.timestamp,
        costUsd: costUsd,
        durationMs: durationMs,
        reasoning: last.reasoning,
        fileEdits: last.fileEdits,
      );
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
        final previous = messages[index];
        messages[index] = ChatMessage(
          role: ChatRole.assistant,
          text: previous.text + chunk.text,
          timestamp: previous.timestamp,
          reasoning: chunk.reasoning ?? previous.reasoning,
          fileEdits: chunk.fileEdits,
          imagePaths: previous.imagePaths,
          authorProfileId: previous.authorProfileId,
          workNodeId: previous.workNodeId,
          consultOfProfileId: previous.consultOfProfileId,
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
