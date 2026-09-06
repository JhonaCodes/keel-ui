import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_edges_painter.dart';

/// El tinte azul del tema se colaba porque cada token de superficie llevaba el
/// canal B 20-40 puntos por encima del R. Eso no se ve leyendo el diff: se ve
/// midiendo el token. Estos asserts son esa medición.
void main() {
  /// Cuánto se aparta un color de ser gris: la distancia entre su canal más
  /// alto y el más bajo. Cero es gris puro.
  int desvioDeGris(Color color) {
    final channels = [
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
    ];
    return channels.reduce((a, b) => a > b ? a : b) -
        channels.reduce((a, b) => a < b ? a : b);
  }

  group('paleta neutra', () {
    /// El margen tolera el redondeo de un gris elegido a ojo, no un tinte.
    const maxDesvio = 4;

    const superficies = <String, Color>{
      'void_': AppColors.void_,
      'bg': AppColors.bg,
      'panel': AppColors.panel,
      'raise': AppColors.raise,
      'rule': AppColors.rule,
      'ink': AppColors.ink,
      'inkSoft': AppColors.inkSoft,
      'inkFaint': AppColors.inkFaint,
      'userBubble': AppColors.userBubble,
      'userBubbleBorder': AppColors.userBubbleBorder,
    };

    test('cada token de superficie y de texto es gris neutro', () {
      for (final entry in superficies.entries) {
        expect(
          desvioDeGris(entry.value),
          lessThanOrEqualTo(maxDesvio),
          reason:
              '${entry.key} tiene tinte: '
              '0x${entry.value.toARGB32().toRadixString(16).toUpperCase()}',
        );
      }
    });

    test('la arista inactiva del mapa tampoco tiñe de azul', () {
      expect(desvioDeGris(kMapIdleEdgeColor), lessThanOrEqualTo(maxDesvio));
    });

    test('la jerarquía de luminancia va de void_ a rule sin invertirse', () {
      final orden = [
        AppColors.void_,
        AppColors.bg,
        AppColors.panel,
        AppColors.raise,
        AppColors.rule,
      ].map((color) => color.computeLuminance()).toList();

      for (var i = 1; i < orden.length; i++) {
        expect(
          orden[i],
          greaterThan(orden[i - 1]),
          reason: 'la superficie $i dejó de ser más clara que la anterior',
        );
      }
    });

    test('el dorado de marca queda intacto', () {
      expect(AppColors.brass, const Color(0xFFD9A93C));
      expect(AppColors.brassDeep, const Color(0xFF6B5420));
      expect(AppColors.onBrass, const Color(0xFF17120A));
      expect(buildAppTheme().colorScheme.primary, const Color(0xFFD9A93C));
    });

    test('los colores semánticos conservan su matiz: son señal, no superficie', () {
      expect(AppColors.added, const Color(0xFF4E9E6A));
      expect(AppColors.removed, const Color(0xFFB85C5C));
    });
  });
}
