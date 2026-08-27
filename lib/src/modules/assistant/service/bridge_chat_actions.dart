import 'dart:convert';

import 'package:keel_ui/src/core/services/agent_bridge_channel.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/service/chat_actions.dart';

/// [ChatActions] for the dedicated assistant window: every intent travels to
/// the MAIN engine over [agentBridgeChannel] (`assistant.*` methods), where
/// the real [AgentsViewModel] executes it. Fire-and-forget on purpose — the
/// result comes back as a pushed [AssistantWindowState] snapshot, never as a
/// return value the UI would wait on.
class BridgeChatActions extends ChatActions {
  const BridgeChatActions();

  void _invoke(String method, Map<String, dynamic> payload) {
    agentBridgeChannel.invokeMethod('assistant.$method', jsonEncode(payload));
  }

  Future<String?> _ask(String method, Map<String, dynamic> payload) {
    return agentBridgeChannel.invokeMethod<String>(
      'assistant.$method',
      jsonEncode(payload),
    );
  }

  @override
  void sendMessage(
    String agentId,
    String text, {
    List<String> imagePaths = const [],
  }) => _invoke('sendMessage', {
    'agentId': agentId,
    'text': text,
    'imagePaths': imagePaths,
  });

  @override
  void sendQueuedMessages(String agentId) =>
      _invoke('sendQueued', {'agentId': agentId});

  @override
  void removeQueuedMessage(String agentId, String messageId) =>
      _invoke('removeQueued', {'agentId': agentId, 'messageId': messageId});

  @override
  void editQueuedMessage(String agentId, String messageId, String text) =>
      _invoke('editQueued', {
        'agentId': agentId,
        'messageId': messageId,
        'text': text,
      });

  @override
  void holdQueuedMessage(String agentId, String messageId) =>
      _invoke('holdQueued', {'agentId': agentId, 'messageId': messageId});

  @override
  void sendQueuedMessageAfterTurn(String agentId, String messageId) => _invoke(
    'sendQueuedAfterTurn',
    {'agentId': agentId, 'messageId': messageId},
  );

  @override
  void sendQueuedMessageNow(String agentId, String messageId) =>
      _invoke('sendQueuedNow', {'agentId': agentId, 'messageId': messageId});

  @override
  void stopAgent(String agentId) => _invoke('stop', {'agentId': agentId});

  @override
  void deleteAgent(String agentId) =>
      _invoke('deleteAgent', {'agentId': agentId});

  @override
  void deleteMessage(String agentId, DateTime timestamp) => _invoke(
    'deleteMessage',
    // µs epoch, not ISO: exact equality against the DateTime main compares.
    {'agentId': agentId, 'timestampUs': timestamp.microsecondsSinceEpoch},
  );

  @override
  void setAgentModel(String agentId, String model) =>
      _invoke('setModel', {'agentId': agentId, 'model': model});

  @override
  void setAgentProvider(String agentId, AgentProvider provider) =>
      _invoke('setProvider', {'agentId': agentId, 'provider': provider.alias});

  @override
  void setAgentEffort(String agentId, String effort) =>
      _invoke('setEffort', {'agentId': agentId, 'effort': effort});

  @override
  void requestCompact(String agentId) =>
      _invoke('requestCompact', {'agentId': agentId});

  @override
  void respondToPermissionRequest(String agentId, {required bool grant}) =>
      _invoke('respondPermission', {'agentId': agentId, 'grant': grant});

  @override
  void setAgentFullFileSystemAccess(String agentId, bool enabled) => _invoke(
    'setFullFileSystemAccess',
    {'agentId': agentId, 'enabled': enabled},
  );

  @override
  void setAgentPlanMode(String agentId, bool enabled) =>
      _invoke('setPlanMode', {'agentId': agentId, 'enabled': enabled});

  @override
  void implementPlan(String agentId) =>
      _invoke('implementPlan', {'agentId': agentId});

  @override
  void keepPlanning(String agentId) =>
      _invoke('keepPlanning', {'agentId': agentId});

  @override
  Future<void> askAboutLine(
    String agentId, {
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) async {
    // Unreachable in practice: the assistant snapshot strips fileEdits, so
    // the inline editor (the only caller) never renders in this window. Kept
    // wired anyway so the port has no dead-end method.
    _invoke('askAboutLine', {
      'agentId': agentId,
      'filePath': filePath,
      'lineNumber': lineNumber,
      'lineContent': lineContent,
      'question': question,
    });
  }

  /// La única llamada del puerto que ESPERA una respuesta: el catálogo lo
  /// arma MAIN, porque este engine no tiene base de datos y sus catálogos
  /// están vacíos. Si el viaje falla, la lista queda vacía y el compositor
  /// sigue siendo un campo de texto normal — nunca rompe el tipeo.
  @override
  Future<List<ChatReferenceSuggestion>> referenceSuggestions(
    ChatReferenceQuery query,
  ) async {
    try {
      final answer = await _ask('referenceSuggestions', query.toJson());
      if (answer == null || answer.isEmpty) return const [];
      final decoded = jsonDecode(answer) as List;
      return [
        for (final entry in decoded)
          ChatReferenceSuggestion.fromJson((entry as Map).cast()),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  void recordManualEdit(String agentId, FileEdit edit) {
    // Same practical unreachability as askAboutLine — see above.
    _invoke('recordManualEdit', {
      'agentId': agentId,
      'filePath': edit.path,
      'beforeContent': edit.beforeContent ?? '',
      'afterContent': edit.afterContent,
    });
  }
}
