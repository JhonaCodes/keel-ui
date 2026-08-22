import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:keel_ui/src/modules/agents/ui/widget/mermaid_diagram.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/svg_diagram.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_document.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

/// El visor del Saber: elige cómo mostrar el documento según su extensión.
/// El markdown usa el mismo renderer que el chat CON su `codeBuilder`, así
/// que un bloque ```mermaid``` o ```svg``` adentro de un `.md` se dibuja como
/// diagrama en vez de quedar como texto.
class KnowledgeDocumentView extends StatelessWidget {
  const KnowledgeDocumentView({super.key, required this.document});

  final KnowledgeDocument document;

  @override
  Widget build(BuildContext context) {
    if (document.problem.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(document.problem, textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocumentHeader(document: document),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SelectionArea(child: _body(context)),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    return switch (document.kind) {
      KnowledgeDocumentKind.markdown => GptMarkdown(
        document.text,
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
      KnowledgeDocumentKind.mermaid => MermaidDiagram(code: document.text),
      KnowledgeDocumentKind.svg => SvgDiagram(code: document.text),
      KnowledgeDocumentKind.image => Image.file(
        File(document.absolutePath),
        errorBuilder: (context, error, stack) =>
            Text('No pude abrir la imagen: $error'),
      ),
      KnowledgeDocumentKind.code => CodeField(
        name: document.language,
        codes: document.text,
      ),
      KnowledgeDocumentKind.unsupported => _UnsupportedDocument(
        document: document,
      ),
    };
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.document});

  final KnowledgeDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.fileName, style: theme.textTheme.titleMedium),
                Text(
                  document.relativePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Abrir con la app del sistema',
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () => KnowledgeService.instance.notifier.openWithSystem(
              document.absolutePath,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un formato que la app no dibuja (PDF, hoja de cálculo, binario). Se dice
/// cuál es y se ofrece abrirlo afuera, en vez de mostrar bytes.
class _UnsupportedDocument extends StatelessWidget {
  const _UnsupportedDocument({required this.document});

  final KnowledgeDocument document;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 40),
          const SizedBox(height: 12),
          Text(
            'Este formato no se dibuja acá.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(document.fileName, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => KnowledgeService.instance.notifier.openWithSystem(
              document.absolutePath,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Abrir con la app del sistema'),
          ),
        ],
      ),
    );
  }
}
