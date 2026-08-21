import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/services/image_export.dart';
import 'package:keel_ui/src/core/services/mermaid_render_service.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/diagram_save_badge.dart';

class MermaidDiagram extends StatefulWidget {
  const MermaidDiagram({super.key, required this.code});

  final String code;

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramState();
}

class _MermaidDiagramState extends State<MermaidDiagram> {
  Future<Uint8List>? _future;

  String _hex(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _future ??= renderMermaidPng(
      widget.code,
      dark: theme.brightness == Brightness.dark,
      backgroundHex: _hex(theme.colorScheme.surfaceContainerHigh),
    );

    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          return Text(
            'No se pudo renderizar el diagrama (${snapshot.error ?? "sin datos"})',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          );
        }

        return DiagramSaveBadge(
          onSave: () => savePngBytes(bytes, suggestedName: 'diagrama.png'),
          child: Image.memory(bytes),
        );
      },
    );
  }
}
