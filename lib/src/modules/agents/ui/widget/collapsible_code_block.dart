import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agents/model/code_block_presentation.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/syntax_highlighted_code_view.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Un bloque ```código``` de un mensaje: una tarjeta compacta de máximo dos
/// filas, nunca el código expandido en el hilo.
///
/// El [CodeField] de gpt_markdown no tiene techo de alto: un `git diff` o el
/// resultado completo de un `Read` pegado en la respuesta de un agente se
/// renderiza entero, y el scroll de la ventana de chat queda atrapado
/// adentro de esa caja. Acá el código nunca se dibuja en el hilo: la tarjeta
/// muestra el lenguaje y la cantidad de líneas, con dos acciones — "Ver"
/// abre el código completo en el panel lateral que ya usa el resto de la
/// app ([showFormPanel], el equivalente de un end drawer), y "Cerrar" saca
/// la tarjeta del mensaje.
class CollapsibleCodeBlock extends StatefulWidget {
  const CollapsibleCodeBlock({
    super.key,
    required this.name,
    required this.code,
  });

  /// El lenguaje escrito después del fence de apertura.
  final String name;

  /// El código en sí.
  final String code;

  @override
  State<CollapsibleCodeBlock> createState() => _CollapsibleCodeBlockState();
}

class _CollapsibleCodeBlockState extends State<CollapsibleCodeBlock> {
  bool _closed = false;

  int get _lineCount => widget.code.split('\n').length;

  CodeBlockPresentation get _presentation =>
      CodeBlockPresentation.from(fenceName: widget.name, source: widget.code);

  Future<void> _ver() => showFormPanel<void>(
    context,
    width: 720,
    child: _CodeBlockPanel(presentation: _presentation),
  );

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final presentation = _presentation;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: 10.smoothBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                presentation.rendersMarkdown
                    ? Icons.article_outlined
                    : Icons.code,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.codeBlockLineCount(presentation.title, _lineCount),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _ver,
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: Text(t.buttonView),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _closed = true),
                icon: const Icon(Icons.close, size: 14),
                label: Text(t.buttonClose),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El código completo, dentro del panel lateral que abre "Ver".
class _CodeBlockPanel extends StatelessWidget {
  const _CodeBlockPanel({required this.presentation});

  final CodeBlockPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(presentation.title)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: presentation.rendersMarkdown
              ? _MarkdownBlockDocument(markdown: presentation.source)
              : SyntaxHighlightedCodeView(
                  language: presentation.language,
                  source: presentation.source,
                ),
        ),
      ),
    );
  }
}

class _MarkdownBlockDocument extends StatelessWidget {
  const _MarkdownBlockDocument({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SelectionArea(
      child: GptMarkdown(
        linkifyBareUrls(markdown),
        style: TextStyle(color: scheme.onSurface, fontSize: 14),
        onLinkTap: (url, _) => openExternalUrl(url),
        codeBuilder: (context, name, code, closed) {
          final nested = CodeBlockPresentation.from(
            fenceName: name,
            source: code,
          );
          return nested.rendersMarkdown
              ? _MarkdownBlockDocument(markdown: nested.source)
              : SyntaxHighlightedCodeView(
                  language: nested.language,
                  source: nested.source,
                );
        },
      ),
    );
  }
}
