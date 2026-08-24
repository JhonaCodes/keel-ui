import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:keel_ui/src/modules/agents/model/highlighted_line.dart';

/// Visor seleccionable que colorea código sin esconder el final de las líneas.
///
/// El contenido se ajusta al ancho disponible. Antes de usar el resultado del
/// parser se comprueba que reconstruya exactamente [source]; ante un lenguaje
/// desconocido o un parseo incompleto se muestra la fuente original en vez de
/// perder texto silenciosamente.
class SyntaxHighlightedCodeView extends StatefulWidget {
  const SyntaxHighlightedCodeView({
    super.key,
    required this.language,
    required this.source,
  });

  final String language;
  final String source;

  @override
  State<SyntaxHighlightedCodeView> createState() =>
      _SyntaxHighlightedCodeViewState();
}

class _SyntaxHighlightedCodeViewState extends State<SyntaxHighlightedCodeView> {
  late List<List<HlSpan>> _highlightedLines;
  bool _copied = false;

  String get _language {
    final language = widget.language.trim();
    return language.isEmpty ? 'plaintext' : language;
  }

  @override
  void initState() {
    super.initState();
    _highlightedLines = _highlight(widget.source, _language);
  }

  @override
  void didUpdateWidget(covariant SyntaxHighlightedCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.language != widget.language) {
      _highlightedLines = _highlight(widget.source, _language);
    }
  }

  List<List<HlSpan>> _highlight(String source, String language) {
    try {
      final highlighted = highlightLines(source, language);
      if (_plainTextOf(highlighted) == source) return highlighted;
    } on Object {
      // Un fence puede traer un identificador que highlight.js no conoce.
      // Mostrar todo sin color es preferible a ocultar o romper contenido.
    }
    return [
      for (final line in source.split('\n')) [HlSpan(line, null)],
    ];
  }

  String _plainTextOf(List<List<HlSpan>> lines) =>
      lines.map((line) => line.map((span) => span.text).join()).join('\n');

  TextSpan _textSpan(BuildContext context) {
    final theme = codeHighlightTheme(Theme.of(context).brightness);
    final baseStyle =
        (theme['root'] ??
                TextStyle(color: Theme.of(context).colorScheme.onSurface))
            .copyWith(
              backgroundColor: Colors.transparent,
              fontFamily: 'JetBrainsMono',
              package: 'gpt_markdown',
              fontSize: 14,
              height: 1.45,
            );
    final children = <TextSpan>[];
    for (var index = 0; index < _highlightedLines.length; index++) {
      children.addAll(renderHighlightedLine(_highlightedLines[index], theme));
      if (index != _highlightedLines.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }
    final highlighted = TextSpan(style: baseStyle, children: children);
    return highlighted.toPlainText() == widget.source
        ? highlighted
        : TextSpan(text: widget.source, style: baseStyle);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('syntax-highlighted-code'),
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CodeViewerHeader(
            language: _language,
            copied: _copied,
            onCopy: _copy,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText.rich(
              _textSpan(context),
              textWidthBasis: TextWidthBasis.parent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeViewerHeader extends StatelessWidget {
  const _CodeViewerHeader({
    required this.language,
    required this.copied,
    required this.onCopy,
  });

  final String language;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(language)),
          TextButton.icon(
            onPressed: onCopy,
            icon: Icon(copied ? Icons.done : Icons.content_paste, size: 16),
            label: Text(copied ? 'Copiado' : 'Copiar código'),
          ),
        ],
      ),
    );
  }
}
