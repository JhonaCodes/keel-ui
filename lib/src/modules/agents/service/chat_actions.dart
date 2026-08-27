import 'dart:async';

import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
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

  /// [imagePaths] are attachments ALREADY stored by
  /// `ChatAttachmentStore` — the port carries paths, never bytes, so the
  /// RPC bridge stays a small JSON payload no matter how big the image is.
  void sendMessage(
    String agentId,
    String text, {
    List<String> imagePaths = const [],
  });

  /// Sends what is queued right now, without waiting for a turn to end —
  /// the escape hatch after stopping an agent mid-turn.
  void sendQueuedMessages(String agentId);

  /// Saca de la cola el mensaje [messageId] antes de que salga.
  void removeQueuedMessage(String agentId, String messageId);

  /// Reescribe un mensaje que todavía no salió.
  void editQueuedMessage(String agentId, String messageId, String text);

  /// Lo devuelve a la espera: sale cuando el usuario diga.
  void holdQueuedMessage(String agentId, String messageId);

  /// Que salga solo apenas el turno en curso entregue el control.
  void sendQueuedMessageAfterTurn(String agentId, String messageId);

  /// Interrumpe el turno en curso para que este mensaje salga ya.
  void sendQueuedMessageNow(String agentId, String messageId);

  void stopAgent(String agentId);
  void deleteAgent(String agentId);
  void deleteMessage(String agentId, DateTime timestamp);
  void setAgentModel(String agentId, String model);
  void setAgentProvider(String agentId, AgentProvider provider);
  void setAgentEffort(String agentId, String effort);
  void requestCompact(String agentId);
  void respondToPermissionRequest(String agentId, {required bool grant});
  void setAgentFullFileSystemAccess(String agentId, bool enabled);
  void setAgentPlanMode(String agentId, bool enabled);

  /// El plan quedó aprobado: sale del modo plan y arranca a implementarlo.
  void implementPlan(String agentId);

  /// Baja la tarjeta y deja el modo plan prendido.
  void keepPlanning(String agentId);
  Future<void> askAboutLine(
    String agentId, {
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  });
  void recordManualEdit(String agentId, FileEdit edit);

  /// Las opciones del autocompletado de referencias (`/`, `@`, `$`, `#`).
  ///
  /// Es lo único del chat que necesita RESPUESTA y no solo disparo: la lista
  /// se dibuja mientras el usuario escribe. Arma el catálogo quien tiene la
  /// base de datos — que en la ventana de Keel AI es el engine principal, no
  /// el que dibuja.
  Future<List<ChatReferenceSuggestion>> referenceSuggestions(
    ChatReferenceQuery query,
  );
}

/// Direct delegation to this engine's [AgentsService] singleton — the only
/// behavior the chat had before the actions port existed. The singleton is
/// touched lazily (inside each call), never at construction, so merely
/// importing this in another engine instantiates nothing.
class LocalChatActions extends ChatActions {
  const LocalChatActions();

  AgentsViewModel get _agents => AgentsService.instance.notifier;

  @override
  void sendMessage(
    String agentId,
    String text, {
    List<String> imagePaths = const [],
  }) => _agents.sendMessage(agentId, text, imagePaths: imagePaths);

  @override
  void sendQueuedMessages(String agentId) =>
      unawaited(_agents.sendQueuedMessages(agentId));

  @override
  void removeQueuedMessage(String agentId, String messageId) =>
      _agents.removeQueuedMessage(agentId, messageId);

  @override
  void editQueuedMessage(String agentId, String messageId, String text) =>
      _agents.editQueuedMessage(agentId, messageId, text);

  @override
  void holdQueuedMessage(String agentId, String messageId) =>
      _agents.holdQueuedMessage(agentId, messageId);

  @override
  void sendQueuedMessageAfterTurn(String agentId, String messageId) =>
      unawaited(_agents.sendQueuedMessageAfterTurn(agentId, messageId));

  @override
  void sendQueuedMessageNow(String agentId, String messageId) =>
      unawaited(_agents.sendQueuedMessageNow(agentId, messageId));

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
  void setAgentProvider(String agentId, AgentProvider provider) =>
      _agents.setAgentProvider(agentId, provider);

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
  void setAgentPlanMode(String agentId, bool enabled) =>
      _agents.setAgentPlanMode(agentId, enabled);

  @override
  void implementPlan(String agentId) => _agents.implementPlan(agentId);

  @override
  void keepPlanning(String agentId) => _agents.keepPlanning(agentId);

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

  @override
  Future<List<ChatReferenceSuggestion>> referenceSuggestions(
    ChatReferenceQuery query,
  ) => ChatReferenceService.suggestions(
    scope: const GlobalReferenceScope(),
    query: query,
  );
}
