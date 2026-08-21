import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/claude_cli_service.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/line_diff.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/repository/agents_repository.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_executor.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_parser.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_retry.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class AgentsViewModel extends ViewModel<AgentsState> {
  AgentsViewModel() : super(const AgentsState());

  AgentsRepository get _repository => AgentsRepository();

  ClaudeCliService get _claude => ClaudeCliService();

  final Map<String, Process> _runningProcesses = {};
  final Set<String> _stoppedAgentIds = {};

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
    String? profileId,
  }) {
    return Agent(
      id: generateUuidV4(),
      name: name,
      model: model,
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

  Future<void> sendMessage(
    String agentId,
    String text, {
    bool isAutoRetry = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final target = data.agents.firstWhere((agent) => agent.id == agentId);
    if (target.isStreaming) return;

    final pendingUserEdit = target.pendingUserEdit;
    if (pendingUserEdit != null) {
      _updateAgent(
        agentId,
        (agent) => agent.copyWith(clearPendingUserEdit: true),
      );
    }
    final promptForModel = pendingUserEdit == null
        ? trimmed
        : '${_describeManualEdit(pendingUserEdit)}\n\n$trimmed';

    _appendMessage(
      agentId,
      ChatMessage(
        // An auto-retry prompt is written by the app, not the human — shown
        // as ChatRole.system so it never reads as something the user typed.
        role: isAutoRetry ? ChatRole.system : ChatRole.user,
        text: trimmed,
        timestamp: DateTime.now(),
      ),
    );
    _setStreaming(agentId, true);
    await _persist();

    final workingDirectory =
        Platform.environment['HOME'] ?? Directory.current.path;
    final pendingFileBeforeContent = <String, String?>{};
    final assistantTextBuffer = StringBuffer();
    final isKeelAi = _isKeelAi(target.profileId);
    final mcpConfig = isKeelAi
        ? AssistantMcpServer.mcpConfigFor(agentId)
        : null;

    final events = _claude.run(
      prompt: promptForModel,
      sessionId: target.sessionId,
      model: target.model,
      fullFileSystemAccess: target.fullFileSystemAccess,
      effort: target.effort,
      extraAllowedTools: [
        ...SettingsService.instance.notifier.data.extraAllowedTools,
        if (mcpConfig != null) ...kKeelAiMcpToolNames,
      ],
      workingDirectory: workingDirectory,
      additionalSystemPrompt: _resolveProfileSystemPrompt(target.profileId),
      mcpConfig: mcpConfig,
      onProcessStarted: (process) => _runningProcesses[agentId] = process,
    );

    var wasStopped = false;
    var calledAnyKeelAiTool = false;
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
              fileEdits: await _collectFileEdits(pendingFileBeforeContent),
            ),
          );
          pendingFileBeforeContent.clear();

        case ClaudeToolUse(name: final name, input: final input):
          if (kKeelAiMcpToolNames.contains(name)) calledAnyKeelAiTool = true;
          _setCurrentActivity(
            agentId,
            AgentToolActivity.fromToolUse(name, input),
          );
          final filePath = _filePathFor(name, input);
          if (filePath != null &&
              !pendingFileBeforeContent.containsKey(filePath)) {
            pendingFileBeforeContent[filePath] = await _readFileSafely(
              filePath,
            );
          }

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
    // Cleared BEFORE the assistant-actions hook, not after: a retry inside
    // that hook calls sendMessage recursively, and sendMessage's own guard
    // (`if (target.isStreaming) return;`) would silently no-op the retry if
    // this agent still looked busy.
    _setStreaming(agentId, false);

    if (isKeelAi) {
      // target.messages was captured before this turn's user message was
      // appended, so it's exactly the prior history — combined with
      // `trimmed`, this covers both "creá una estación" as the direct
      // request AND "sí, dale" a couple of turns after Keel AI already
      // asked a clarifying question about one.
      final recentUserTexts = [
        trimmed,
        ...target.messages.reversed
            .where((message) => message.role == ChatRole.user)
            .take(2)
            .map((message) => message.text),
      ];
      await _runAssistantActions(
        agentId,
        recentUserTexts: recentUserTexts,
        assistantText: assistantTextBuffer.toString(),
        // A retry only makes sense when NEITHER path fired: no block in the
        // text AND no real tool call either. If a tool ran, the live trace
        // from `appendSystemNote` already told the user what happened, even
        // if the model's own prose is otherwise empty or vague.
        allowRetry: !isAutoRetry && !wasStopped && !calledAnyKeelAiTool,
      );
    }

    await _persist();
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

  bool _isKeelAi(String? profileId) {
    if (profileId == null) return false;
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    return profiles
            .where((profile) => profile.id == profileId)
            .firstOrNull
            ?.name ==
        kKeelAiHandle;
  }

  /// Reads whatever Keel AI wrote this turn for action blocks and runs them.
  /// Scoped to the reserved profile only — an ordinary agent's reply is
  /// never scanned, even if its text happens to contain something shaped
  /// like a block.
  ///
  /// If the reply has none AND any of [recentUserTexts] read like a
  /// creation request, sends exactly one automatic follow-up asking Keel AI
  /// to redo it as a block — this is a format miss, not a misunderstanding,
  /// and the retry prompt is visible in the thread like any other message,
  /// never silent background work. [allowRetry] is false on that follow-up
  /// call itself, so this never loops.
  Future<void> _runAssistantActions(
    String agentId, {
    required List<String> recentUserTexts,
    required String assistantText,
    required bool allowRetry,
  }) async {
    final actions = parseAssistantActions(assistantText);
    if (actions.isEmpty) {
      if (allowRetry && looksLikeCreationRequest(recentUserTexts)) {
        await sendMessage(agentId, kBlockRetryPrompt, isAutoRetry: true);
      }
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

  /// Concatenates [profileId]'s own `systemPrompt` with the content of its
  /// registered skills and rules, for injection into the agent's system
  /// prompt. Selection is static — decided when the profile was
  /// configured, never inferred by the model at runtime.
  String? _resolveProfileSystemPrompt(String? profileId) {
    if (profileId == null) return null;

    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    final profileIndex = profiles.indexWhere(
      (profile) => profile.id == profileId,
    );
    if (profileIndex == -1) return null;
    final profile = profiles[profileIndex];

    final skills = SkillsService.instance.notifier.data.skills;
    final rules = RulesService.instance.notifier.data.rules;
    final buffer = StringBuffer();
    if (profile.systemPrompt.isNotEmpty) {
      buffer.writeln(profile.systemPrompt);
    }
    for (final skillName in profile.skills) {
      final skillIndex = skills.indexWhere((skill) => skill.name == skillName);
      if (skillIndex == -1) continue;
      final skill = skills[skillIndex];
      if (skill.content.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(skill.content);
    }
    for (final ruleName in profile.rules) {
      final ruleIndex = rules.indexWhere((rule) => rule.name == ruleName);
      if (ruleIndex == -1) continue;
      final rule = rules[ruleIndex];
      if (rule.content.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(rule.content);
    }
    final combined = buffer.toString().trim();
    return combined.isEmpty ? null : combined;
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

  String? _filePathFor(String toolName, Map<String, dynamic>? input) {
    return switch (toolName) {
      'Write' || 'Edit' || 'MultiEdit' => input?['file_path'] as String?,
      'NotebookEdit' => input?['notebook_path'] as String?,
      _ => null,
    };
  }

  static const _maxDiffableFileBytes = 300000;

  Future<String?> _readFileSafely(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (stat.size > _maxDiffableFileBytes) return null;
      return await file.readAsString();
    } catch (error) {
      Log.w('Could not read $path for diff capture: $error');
      return null;
    }
  }

  Future<List<FileEdit>> _collectFileEdits(
    Map<String, String?> beforeContentByPath,
  ) async {
    final edits = <FileEdit>[];
    for (final path in beforeContentByPath.keys) {
      final after = await _readFileSafely(path);
      edits.add(
        FileEdit(
          path: path,
          beforeContent: beforeContentByPath[path],
          afterContent: after ?? '',
        ),
      );
    }
    return edits;
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
