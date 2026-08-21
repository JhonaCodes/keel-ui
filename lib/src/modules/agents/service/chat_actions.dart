import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

/// Every intent the chat UI ([ChatView] and its bubbles) can fire, abstracted
/// from WHERE the real [AgentsViewModel] lives. In the main window that's the
/// local singleton ([LocalChatActions], the default — existing callers don't
/// change); in the dedicated assistant window it's an RPC bridge to the main
/// engine, because a sub-window runs its own Flutter engine whose singletons
/// are empty replicas.
abstract class ChatActions {
  const ChatActions();

  void sendMessage(String agentId, String text);
  void stopAgent(String agentId);
  void deleteAgent(String agentId);
  void deleteMessage(String agentId, DateTime timestamp);
  void setAgentModel(String agentId, String model);
  void setAgentEffort(String agentId, String effort);
  void requestCompact(String agentId);
  void respondToPermissionRequest(String agentId, {required bool grant});
  void setAgentFullFileSystemAccess(String agentId, bool enabled);
  Future<void> askAboutLine(
    String agentId, {
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  });
  void recordManualEdit(String agentId, FileEdit edit);
}

/// Direct delegation to this engine's [AgentsService] singleton — the only
/// behavior the chat had before the actions port existed. The singleton is
/// touched lazily (inside each call), never at construction, so merely
/// importing this in another engine instantiates nothing.
class LocalChatActions extends ChatActions {
  const LocalChatActions();

  AgentsViewModel get _agents => AgentsService.instance.notifier;

  @override
  void sendMessage(String agentId, String text) =>
      _agents.sendMessage(agentId, text);

  @override
  void stopAgent(String agentId) => _agents.stopAgent(agentId);

  @override
  void deleteAgent(String agentId) => _agents.deleteAgent(agentId);

  @override
  void deleteMessage(String agentId, DateTime timestamp) =>
      _agents.deleteMessage(agentId, timestamp);

  @override
  void setAgentModel(String agentId, String model) =>
      _agents.setAgentModel(agentId, model);

  @override
  void setAgentEffort(String agentId, String effort) =>
      _agents.setAgentEffort(agentId, effort);

  @override
  void requestCompact(String agentId) => _agents.requestCompact(agentId);

  @override
  void respondToPermissionRequest(String agentId, {required bool grant}) =>
      _agents.respondToPermissionRequest(agentId, grant: grant);

  @override
  void setAgentFullFileSystemAccess(String agentId, bool enabled) =>
      _agents.setAgentFullFileSystemAccess(agentId, enabled);

  @override
  Future<void> askAboutLine(
    String agentId, {
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) => _agents.askAboutLine(
    agentId,
    filePath: filePath,
    lineNumber: lineNumber,
    lineContent: lineContent,
    question: question,
  );

  @override
  void recordManualEdit(String agentId, FileEdit edit) =>
      _agents.recordManualEdit(agentId, edit);
}
