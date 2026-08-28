import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/message_block.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_image_attachments.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/file_editor_content.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/inline_file_editor.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';

/// The rendered contents of a chat message — the turn's blocks in the order
/// the model emitted them, plus the duration footer. Shared by the 1:1 agent
/// bubble and the workstation bubble, which differ in their chrome, not their
/// body.
///
/// The order lives HERE, once. Both bubbles used to render all the prose and
/// then all the editor cards underneath it, so a turn that wrote, edited and
/// wrote again read as one flat block with the diffs dumped at the end.
///
/// Applies to EVERY message, yours included: a prompt written in markdown
/// reads as markdown, not as a wall of `#` and `**`.
class ChatMessageBody extends StatelessWidget {
  const ChatMessageBody({
    super.key,
    required this.message,
    required this.foreground,
    required this.fontScale,
    required this.workingDirectory,
    required this.onAskAboutLine,
    required this.onManualEditSaved,
    this.windowAgentId,
  });

  final ChatMessage message;
  final Color foreground;
  final double fontScale;

  /// The directory the turn that wrote this message ran in — what a reported
  /// relative path resolves against.
  final String? workingDirectory;

  final AskAboutLineCallback onAskAboutLine;
  final ManualEditSavedCallback onManualEditSaved;

  /// Set only by the 1:1 chat, where an edit can be popped out into its own
  /// window.
  final String? windowAgentId;

  @override
  Widget build(BuildContext context) {
    final base = 14 * fontScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Above the text: what you attached is what you were talking about.
        ChatImageAttachments(paths: message.imagePaths),
        for (final block in message.blocks)
          switch (block) {
            MessageTextBlock(text: final text) => MarkdownText(
              text,
              color: foreground,
              fontSize: base,
            ),
            MessageFileEditBlock(edit: final edit) => InlineFileEditor(
              editAsReported: edit,
              workingDirectory: workingDirectory,
              windowAgentId: windowAgentId,
              onAskAboutLine: onAskAboutLine,
              onManualEditSaved: onManualEditSaved,
            ),
          },
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
