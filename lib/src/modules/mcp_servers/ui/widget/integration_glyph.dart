import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';

/// Dos letras sobre un color de la paleta, en vez del logo del servicio.
///
/// Es una decisión, no una limitación: un logo habría que bajarlo o
/// empaquetarlo, se desactualiza cuando la marca cambia, y una app que
/// promete no salir a la red por su cuenta no debería hacerlo para dibujar
/// un ícono.
class IntegrationGlyph extends StatelessWidget {
  const IntegrationGlyph({
    super.key,
    required this.glyph,
    required this.colorIndex,
    this.size = 30,
  });

  /// El glifo de una ficha del catálogo, o las dos primeras letras del
  /// nombre para un servidor registrado a mano.
  IntegrationGlyph.forEntry(McpCatalogEntry entry, {super.key, this.size = 30})
    : glyph = entry.glyph,
      colorIndex = entry.colorIndex;

  IntegrationGlyph.forName(String name, {super.key, this.size = 30})
    : glyph = _initialsOf(name),
      colorIndex = _colorOf(name);

  final String glyph;
  final int colorIndex;
  final double size;

  static String _initialsOf(String name) {
    final letters = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (letters.isEmpty) return '??';
    if (letters.length == 1) return letters.toUpperCase();
    return letters.substring(0, 2).toUpperCase();
  }

  /// Estable por nombre: el mismo servidor conserva su color entre
  /// arranques, que es lo que lo hace reconocible de un vistazo.
  static int _colorOf(String name) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % kProjectMemberPalette.length;
  }

  @override
  Widget build(BuildContext context) {
    final color = memberColorFor(colorIndex);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
