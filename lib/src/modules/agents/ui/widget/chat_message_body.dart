import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/mermaid_diagram.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/svg_diagram.dart';

/// The rendered contents of a chat message — markdown with diagram-aware code
/// blocks, plus the cost/duration footer. Shared by the 1:1 agent bubble and
/// the workstation bubble, which differ in their chrome, not their body.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GptMarkdown(
          message.text,
          style: TextStyle(color: foreground, fontSize: 14 * fontScale),
          codeBuilder: (context, name, code, closed) {
            if (closed) {
              switch (name.toLowerCase()) {
                case 'svg':
                  return SvgDiagram(code: code);
                case 'mermaid':
                  return MermaidDiagram(code: code);
              }
            }
            return CodeField(name: name, codes: code);
          },
        ),
        if (message.costUsd != null) ...[
          const SizedBox(height: 6),
          Text(
            '\$${message.costUsd!.toStringAsFixed(2)} · '
            '${((message.durationMs ?? 0) / 1000).round()}s',
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
