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
/// Three markers, matching the flow: the workflow starting, a step finishing
/// and passing to the next, and a consult returning control to the step owner.
List<ThreadEntry> buildThreadEntries({
  required List<ChatMessage> messages,
  required Workflow? workflow,
}) {
  final entries = <ThreadEntry>[];
  int? lastStepIndex;
  var wasConsult = false;
  var openedFlow = false;

  for (final message in messages) {
    final isAssistant = message.role == ChatRole.assistant;
    final stepIndex = message.stepIndex;
    final isConsult = message.consultOfProfileId != null;

    if (isAssistant && !openedFlow && workflow != null) {
      entries.add(
        ThreadHandoff(
          '${workflow.name} · ${workflow.steps.length} pasos',
          message.timestamp,
        ),
      );
      openedFlow = true;
    }

    if (isAssistant && !isConsult) {
      if (wasConsult && stepIndex != null) {
        entries.add(
          ThreadHandoff('vuelve al paso ${stepIndex + 1}', message.timestamp),
        );
      } else if (lastStepIndex != null &&
          stepIndex != null &&
          stepIndex > lastStepIndex) {
        entries.add(
          ThreadHandoff(
            'paso ${lastStepIndex + 1} listo → paso ${stepIndex + 1}',
            message.timestamp,
          ),
        );
      }
      lastStepIndex = stepIndex ?? lastStepIndex;
    }

    entries.add(ThreadMessage(message));
    if (isAssistant) wasConsult = isConsult;
  }

  return entries;
}
