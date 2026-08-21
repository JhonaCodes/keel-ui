import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:keel_ui/src/core/services/image_export.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/diagram_save_badge.dart';

class SvgDiagram extends StatefulWidget {
  const SvgDiagram({super.key, required this.code});

  final String code;

  @override
  State<SvgDiagram> createState() => _SvgDiagramState();
}

class _SvgDiagramState extends State<SvgDiagram> {
  final _boundaryKey = GlobalKey();

  Future<void> _save() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    await savePngBytes(
      byteData.buffer.asUint8List(),
      suggestedName: 'diagrama.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DiagramSaveBadge(
      onSave: _save,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: SvgPicture.string(
            widget.code,
            placeholderBuilder: (context) => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorBuilder: (context, error, stackTrace) => Text(
              'No se pudo renderizar el SVG',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
