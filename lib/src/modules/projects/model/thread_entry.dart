import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// One row of the channel: either a message, or the thin divider that marks
/// where the work changed hands.
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

/// Interleaves the session's messages with hand-off markers, so the thread shows
/// *why* the speaker changed without any of that state having to be recorded
/// while the session ran — it is all derivable from the messages themselves.
///
/// Markers show an adaptive case and consultations without implying a fixed
/// sequence of roles.
List<ThreadEntry> buildThreadEntries({
  required List<ChatMessage> messages,
  required Workflow? workflow,
}) {
  final entries = <ThreadEntry>[];
  String? lastNodeId;
  var wasConsult = false;
  var openedFlow = false;

  for (final message in messages) {
    final isAssistant = message.role == ChatRole.assistant;
    final nodeId = message.workNodeId;
    final isConsult = message.consultOfProfileId != null;

    if (isAssistant && !openedFlow && workflow != null) {
      entries.add(
        ThreadHandoff(
          '${workflow.name} · resolución adaptativa',
          message.timestamp,
        ),
      );
      openedFlow = true;
    }

    if (isAssistant && !isConsult) {
      if (wasConsult && nodeId != null) {
        entries.add(ThreadHandoff('vuelve al responsable', message.timestamp));
      } else if (lastNodeId != null && nodeId != null && lastNodeId != nodeId) {
        entries.add(
          ThreadHandoff('evidencia nueva → siguiente nodo', message.timestamp),
        );
      }
      lastNodeId = nodeId ?? lastNodeId;
    }

    entries.add(ThreadMessage(message));
    if (isAssistant) wasConsult = isConsult;
  }

  return entries;
}
