import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_image_attachments.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';

/// The rendered contents of a chat message — markdown with diagram-aware code
/// blocks, plus the cost/duration footer. Shared by the 1:1 agent bubble and
/// the workstation bubble, which differ in their chrome, not their body.
///
/// Applies to EVERY message, yours included: a prompt written in markdown
/// reads as markdown, not as a wall of `#` and `**`.
class ChatMessageBody extends StatelessWidget {
  const ChatMessageBody({
    super.key,
    required this.message,
    required this.foreground,
    required this.fontScale,
  });

  final ChatMessage message;
  final Color foreground;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final base = 14 * fontScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Above the text: what you attached is what you were talking about.
        ChatImageAttachments(paths: message.imagePaths),
        MarkdownText(message.text, color: foreground, fontSize: base),
        // Cuánto tardó, y nada más. La plata que costó el turno no cambia
        // ninguna decisión mientras leés el hilo, y estaba en cada burbuja.
        if (message.durationMs != null) ...[
          const SizedBox(height: 6),
          Text(
            '${(message.durationMs! / 1000).round()}s',
            style: TextStyle(
              fontSize: 11 * fontScale,
              color: foreground.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
