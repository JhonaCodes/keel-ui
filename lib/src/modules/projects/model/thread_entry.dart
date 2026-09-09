import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/service/resolution_engine.dart'
    show kLegacyCapabilityIds;
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// One row of the channel: a message, the thin divider that marks where the
/// work changed hands, or a subagent a member opened.
sealed class ThreadEntry {
  const ThreadEntry();
}

class ThreadMessage extends ThreadEntry {
  final ChatMessage message;
  const ThreadMessage(this.message);
}

class ThreadHandoff extends ThreadEntry {
  final String label;
  final DateTime at;
  const ThreadHandoff(this.label, this.at);
}

class ThreadSubagent extends ThreadEntry {
  final SessionSubagent subagent;
  const ThreadSubagent(this.subagent);
}

/// Qué se ve del hilo. Vacío = todo, como siempre.
///
/// Existe porque con cuatro agentes y doscientos mensajes la única
/// navegación era el scroll: no había forma de ver «solo lo que dijo el
/// auditor» o «solo el nodo de entrega» sin cambiar a la pestaña del mapa.
/// Es estado local de la vista, no de la sesión.
class ThreadFilter {
  /// Autores (ids de perfil) a mostrar; vacío = todos. Los mensajes del
  /// usuario se muestran siempre: son lo que se pidió.
  final Set<String> authorIds;

  /// Nodos de resolución a mostrar; vacío = todos.
  final Set<String> nodeIds;

  /// Mensajes del sistema y de error.
  final bool showSystem;

  /// Los subagentes, intercalados por hora de arranque.
  final bool showSubagents;

  const ThreadFilter({
    this.authorIds = const {},
    this.nodeIds = const {},
    this.showSystem = true,
    this.showSubagents = false,
  });

  bool get isDefault =>
      authorIds.isEmpty && nodeIds.isEmpty && showSystem && !showSubagents;

  ThreadFilter copyWith({
    Set<String>? authorIds,
    Set<String>? nodeIds,
    bool? showSystem,
    bool? showSubagents,
  }) => ThreadFilter(
    authorIds: authorIds ?? this.authorIds,
    nodeIds: nodeIds ?? this.nodeIds,
    showSystem: showSystem ?? this.showSystem,
    showSubagents: showSubagents ?? this.showSubagents,
  );

  bool admits(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    final isAgent = message.role == ChatRole.assistant;
    // Con un autor elegido, lo del sistema es ruido: se ve al agente y al
    // usuario, nada más.
    if (!isUser && !isAgent && (!showSystem || authorIds.isNotEmpty)) {
      return false;
    }
    if (authorIds.isNotEmpty && isAgent) {
      if (!authorIds.contains(message.authorProfileId)) return false;
    }
    if (nodeIds.isNotEmpty && !isUser) {
      if (!nodeIds.contains(message.workNodeId)) return false;
    }
    return true;
  }

  bool admitsSubagent(SessionSubagent subagent) {
    if (!showSubagents) return false;
    if (authorIds.isNotEmpty && !authorIds.contains(subagent.parentProfileId)) {
      return false;
    }
    if (nodeIds.isNotEmpty && !nodeIds.contains(subagent.parentWorkNodeId)) {
      return false;
    }
    return true;
  }
}

/// El título visible de un nodo: el de su capacidad, con los alias viejos
/// resueltos; el id pelado si el workflow ya no lo tiene.
String nodeTitleFor(Workflow? workflow, String nodeId) {
  if (workflow == null) return nodeId;
  final resolved = kLegacyCapabilityIds[nodeId] ?? nodeId;
  final capabilities = workflow.capabilities.isEmpty
      ? defaultWorkflowCapabilities(workflow.kind, workflow.policy.resolutionRole)
      : workflow.capabilities;
  for (final capability in capabilities) {
    if (capability.id == nodeId || capability.id == resolved) {
      return capability.title.isEmpty ? nodeId : capability.title;
    }
  }
  return nodeId;
}

/// Interleaves the session's messages with hand-off markers, so the thread shows
/// *why* the speaker changed without any of that state having to be recorded
/// while the session ran — it is all derivable from the messages themselves.
///
/// Markers show an adaptive case and consultations without implying a fixed
/// sequence of roles. With [filter], only what it admits is listed, and the
/// subagents it admits are interleaved by their start time.
/// The three handoff captions the thread draws. They arrive already resolved
/// instead of being built here, because this function is pure model code and
/// has no [BuildContext] to reach the localizations from.
class ThreadLabels {
  const ThreadLabels({
    required this.adaptiveResolution,
    required this.backToOwner,
    required this.nextNode,
  });

  /// Receives the workflow's name.
  final String Function(String) adaptiveResolution;
  final String backToOwner;

  /// Receives the next node's resolved title.
  final String Function(String) nextNode;
}

List<ThreadEntry> buildThreadEntries({
  required List<ChatMessage> messages,
  required Workflow? workflow,
  required ThreadLabels labels,
  List<SessionSubagent> subagents = const [],
  ThreadFilter filter = const ThreadFilter(),
}) {
  final entries = <ThreadEntry>[];
  String? lastNodeId;
  var wasConsult = false;
  var openedFlow = false;
  final pendingSubagents = [
    for (final subagent in subagents)
      if (filter.admitsSubagent(subagent)) subagent,
  ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  void flushSubagentsBefore(DateTime at) {
    while (pendingSubagents.isNotEmpty &&
        !pendingSubagents.first.startedAt.isAfter(at)) {
      entries.add(ThreadSubagent(pendingSubagents.removeAt(0)));
    }
  }

  for (final message in messages) {
    if (!filter.admits(message)) continue;
    flushSubagentsBefore(message.timestamp);
    final isAssistant = message.role == ChatRole.assistant;
    final nodeId = message.workNodeId;
    final isConsult = message.consultOfProfileId != null;

    if (isAssistant && !openedFlow && workflow != null) {
      entries.add(
        ThreadHandoff(
          labels.adaptiveResolution(workflow.name),
          message.timestamp,
        ),
      );
      openedFlow = true;
    }

    if (isAssistant && !isConsult) {
      if (wasConsult && nodeId != null) {
        entries.add(ThreadHandoff(labels.backToOwner, message.timestamp));
      } else if (lastNodeId != null && nodeId != null && lastNodeId != nodeId) {
        entries.add(
          ThreadHandoff(
            labels.nextNode(nodeTitleFor(workflow, nodeId)),
            message.timestamp,
          ),
        );
      }
      lastNodeId = nodeId ?? lastNodeId;
    }

    entries.add(ThreadMessage(message));
    if (isAssistant) wasConsult = isConsult;
  }
  for (final subagent in pendingSubagents) {
    entries.add(ThreadSubagent(subagent));
  }

  return entries;
}
