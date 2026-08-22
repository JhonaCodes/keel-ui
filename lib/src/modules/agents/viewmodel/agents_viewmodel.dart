import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/claude_cli_service.dart';
import 'package:keel_ui/src/core/services/codex_cli_service.dart';
import 'package:keel_ui/src/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/line_diff.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/model/queued_message.dart';
import 'package:keel_ui/src/modules/agents/repository/agents_repository.dart';
import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
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

  ClaudeCliService get _claude => ClaudeCliService();

  final Map<String, Process> _runningProcesses = {};
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
    unawaited(_repository.save(agents));
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
    String? profileId,
  }) {
    final agent = _buildAgent(
      name,
      model: model,
      fullFileSystemAccess: fullFileSystemAccess,
      effort: effort,
      profileId: profileId,
    );
    final agents = [...data.agents, agent];
    updateState(data.copyWith(agents: agents));
    unawaited(_repository.save(agents));
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
    unawaited(_persist());
  }

  void setAgentEffort(String agentId, String effort) {
    final index = data.agents.indexWhere((agent) => agent.id == agentId);
    if (index == -1 || data.agents[index].effort == effort) return;

    _updateAgent(agentId, (agent) => agent.copyWith(effort: effort));
    unawaited(_persist());
  }

  void setAgentFullFileSystemAccess(String agentId, bool enabled) {
    _updateAgent(
      agentId,
      (agent) => agent.copyWith(fullFileSystemAccess: enabled),
    );
    unawaited(_persist());
  }

  void respondToPermissionRequest(String agentId, {required bool grant}) {
    final target = data.agents.firstWhere((agent) => agent.id == agentId);
    final request = target.pendingPermission;
    if (request == null) return;

    _updateAgent(
      agentId,
      (agent) => agent.copyWith(clearPendingPermission: true),
    );
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

  void deleteAgent(String id) {
    final agents = data.agents.where((agent) => agent.id != id).toList();
    final selectedAgentId = data.selectedAgentId == id
        ? null
        : data.selectedAgentId;
    updateState(AgentsState(agents: agents, selectedAgentId: selectedAgentId));
    unawaited(_repository.save(agents));
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
    unawaited(_persist());
  }

  void requestCompact(String agentId) {
    unawaited(sendMessage(agentId, '/compact'));
  }

  void stopAgent(String agentId) {
    final process = _runningProcesses.remove(agentId);
    if (process == null) return;

    _stoppedAgentIds.add(agentId);
    process.kill();

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
    unawaited(_persist());
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
    final promptForModel = [
      if (pendingUserEdit != null) _describeManualEdit(pendingUserEdit),
      if (trimmed.isNotEmpty) trimmed,
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
    _setStreaming(agentId, true);
    await _persist();

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
    // Los guardarraíles del turno. Se resuelven ACÁ, con el catálogo y los
    // secrets a mano, y lo que llega al CLI son archivos ya escritos.
    final turnHooks = await _resolveTurnHooks(target);
    for (final note in turnHooks.notes) {
      appendSystemNote(agentId, note);
    }

    final events = target.provider == AgentProvider.codex
        ? CodexCliService().run(
            prompt: promptForModel,
            workingDirectory: workingDirectory,
            fullFileSystemAccess: target.fullFileSystemAccess,
            model: target.model,
            sessionId: target.sessionId,
            additionalSystemPrompt: _resolveProfileSystemPrompt(
              target.profileId,
            ),
            hooksConfig: turnHooks.codexConfig,
            hookFiles: turnHooks.files,
            onProcessStarted: (process) => _runningProcesses[agentId] = process,
          )
        : _claude.run(
            prompt: promptForModel,
            sessionId: target.sessionId,
            model: target.model,
            fullFileSystemAccess: target.fullFileSystemAccess,
            effort: target.effort,
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
            workingDirectory: workingDirectory,
            additionalSystemPrompt: _resolveProfileSystemPrompt(
              target.profileId,
            ),
            mcpConfig: mcpConfig,
            hooksSettings: turnHooks.claudeSettings,
            hookFiles: turnHooks.files,
            onProcessStarted: (process) => _runningProcesses[agentId] = process,
          );

    var wasStopped = false;
    await for (final event in events) {
      if (_stoppedAgentIds.remove(agentId)) {
        wasStopped = true;
        break;
      }
      switch (event) {
        case ClaudeSessionStarted(sessionId: final sessionId):
          _updateAgent(
            agentId,
            (agent) => agent.copyWith(sessionId: sessionId),
          );

        case ClaudeAssistantText(text: final chunk):
          _setCurrentActivity(agentId, null);
          assistantTextBuffer.writeln(chunk);
          _appendMessage(
            agentId,
            ChatMessage(
              role: ChatRole.assistant,
              text: chunk,
              timestamp: DateTime.now(),
              reasoning: _consumeLiveReasoning(agentId),
              fileEdits: await fileEdits.collect(),
            ),
          );

        case ClaudeToolUse(name: final name, input: final input):
          _setCurrentActivity(
            agentId,
            AgentToolActivity.fromToolUse(name, input),
          );
          final filePath = FileEditCollector.filePathFor(name, input);
          if (filePath != null) await fileEdits.noteBeforeEdit(filePath);

        case ClaudeReasoningChunk(text: final chunk):
          _appendLiveReasoning(agentId, chunk);

        case ClaudeContextUsage(
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

        case ClaudePermissionDenied(
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

        case ClaudeTurnCompleted(
          isError: final isError,
          costUsd: final costUsd,
          durationMs: final durationMs,
        ):
          if (isError) {
            _appendMessage(
              agentId,
              ChatMessage(
                role: ChatRole.error,
                text: 'claude reportó un error en este turno.',
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

        case ClaudeFailure(message: final message):
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

    _runningProcesses.remove(agentId);
    _setCurrentActivity(agentId, null);
    _updateAgent(agentId, (agent) => agent.copyWith(clearLiveReasoning: true));
    _setStreaming(agentId, false);

    if (isKeelAi) {
      await _runAssistantActions(
        agentId,
        assistantText: assistantTextBuffer.toString(),
      );
    }

    await _persist();

    // Whatever the user typed during the turn goes out now — unless they
    // STOPPED the agent, which is a deliberate "take control": firing a new
    // turn right after would be the opposite of what the stop button means.
    // Those messages stay queued with an explicit "Enviar ahora".
    if (!wasStopped) unawaited(sendQueuedMessages(agentId));
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

  /// Drops one queued message before it is sent — the user changed their
  /// mind about the correction they typed mid-turn.
  void removeQueuedMessage(String agentId, int index) {
    _updateAgent(agentId, (agent) {
      if (index < 0 || index >= agent.queuedMessages.length) return agent;
      final queued = [...agent.queuedMessages]..removeAt(index);
      return agent.copyWith(queuedMessages: queued);
    });
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
    }

    final combined = buffer.toString().trim();
    return combined.isEmpty ? null : combined;
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

  void _setStreaming(String agentId, bool isStreaming) {
    _updateAgent(agentId, (agent) => agent.copyWith(isStreaming: isStreaming));
  }

  void _updateAgent(String agentId, Agent Function(Agent agent) transform) {
    final agents = data.agents
        .map((agent) => agent.id == agentId ? transform(agent) : agent)
        .toList();
    updateState(data.copyWith(agents: agents));
  }

  Future<void> _persist() => _repository.save(data.agents);
}

mixin AgentsService {
  static final ReactiveNotifier<AgentsViewModel> instance =
      ReactiveNotifier<AgentsViewModel>(() => AgentsViewModel());
}
