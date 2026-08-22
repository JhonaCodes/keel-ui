import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_image_attachments.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/mermaid_diagram.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/svg_diagram.dart';
import 'package:keel_ui/src/shared/shared.dart';

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
        GptMarkdownTheme(
          // Sin esto los encabezados salen del textTheme de Material: un `#`
          // se pinta como headlineLarge (32px) dentro de una burbuja cuyo
          // párrafo mide 12.6px. La jerarquía tiene que ser relativa al
          // tamaño del chat, y en el color de ESTA burbuja — el markdown de
          // un mensaje tuyo vive sobre otro fondo que el del agente.
          gptThemeData: GptMarkdownTheme.of(context).copyWith(
            h1: _heading(base * 1.45),
            h2: _heading(base * 1.28),
            h3: _heading(base * 1.14),
            h4: _heading(base * 1.05),
            h5: _heading(base),
            h6: _heading(base),
            highlightColor: foreground.withValues(alpha: 0.14),
            hrLineColor: foreground.withValues(alpha: 0.25),
            linkColor: Theme.of(context).colorScheme.primary,
            linkHoverColor: Theme.of(context).colorScheme.primary,
          ),
          child: GptMarkdown(
            // El renderer solo hace clickeable lo que ya trae sintaxis de
            // enlace, y las URLs que importan llegan peladas: el PR que abre
            // el último paso viene tal como lo imprime `gh`.
            linkifyBareUrls(message.text),
            style: TextStyle(color: foreground, fontSize: base),
            onLinkTap: (url, _) => openExternalUrl(url),
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

  /// Un encabezado de chat: más grande y más pesado que el párrafo, pero
  /// dentro de la misma escala. Un `#` no es un titular de portada.
  TextStyle _heading(double size) => TextStyle(
    color: foreground,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
}
