import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';

/// Tokens por día, apilados por modelo.
///
/// Un `CustomPainter` y no un paquete de charts: el repo ya dibuja a mano
/// (`SessionGraphPainter`), son catorce barras, y una dependencia de gráficos
/// para esto traería cien widgets que nadie más va a usar.
class UsageBars extends StatelessWidget {
  const UsageBars({super.key, required this.days, required this.models});

  final List<DayUsage> days;
  final List<String> models;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 168,
      child: CustomPaint(
        size: Size.infinite,
        painter: _UsageBarsPainter(
          days: days,
          models: models,
          grid: scheme.outlineVariant,
          ink: scheme.outline,
          colorOf: colorForModel,
        ),
      ),
    );
  }
}

/// El color de un modelo, estable entre arranques.
///
/// Sale del nombre y no de la posición: si un día no usaste opus, el resto
/// de los modelos no tiene que cambiar de color.
Color colorForModel(String model) {
  var hash = 0;
  for (final unit in model.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return memberColorFor(hash % kProjectMemberPalette.length);
}

class _UsageBarsPainter extends CustomPainter {
  _UsageBarsPainter({
    required this.days,
    required this.models,
    required this.grid,
    required this.ink,
    required this.colorOf,
  });

  final List<DayUsage> days;
  final List<String> models;
  final Color grid;
  final Color ink;
  final Color Function(String) colorOf;

  static const _axisWidth = 46.0;
  static const _labelHeight = 20.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    final top = 8.0;
    final baseline = size.height - _labelHeight;
    final plotHeight = baseline - top;
    final plotWidth = size.width - _axisWidth;
    if (plotHeight <= 0 || plotWidth <= 0) return;

    final peak = days.fold(
      0,
      (best, day) => day.total > best ? day.total : best,
    );
    // Sin actividad no se dibujan barras de altura cero: se dibuja el eje y
    // se deja que el texto de arriba explique por qué está vacío.
    final scale = peak == 0 ? 0.0 : plotHeight / peak;

    final linePaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = baseline - plotHeight * fraction;
      canvas.drawLine(Offset(_axisWidth, y), Offset(size.width, y), linePaint);
      _label(
        canvas,
        _tokens((peak * fraction).round()),
        0,
        y - 6,
        _axisWidth - 8,
        TextAlign.right,
      );
    }

    final slot = plotWidth / days.length;
    final barWidth = (slot - _gap).clamp(2.0, 44.0);

    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      final x = _axisWidth + slot * index + (slot - barWidth) / 2;
      var y = baseline;

      if (day.total == 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, baseline - 2, barWidth, 2),
          Paint()..color = grid,
        );
      } else {
        // De abajo hacia arriba en el orden de la leyenda, para que las dos
        // se lean juntas sin tener que buscar.
        for (final model in models.reversed) {
          final tokens = day.byModel[model] ?? 0;
          if (tokens == 0) continue;
          final height = tokens * scale;
          y -= height;
          canvas.drawRect(
            Rect.fromLTWH(x, y, barWidth, height),
            Paint()..color = colorOf(model),
          );
        }
      }

      _label(
        canvas,
        '${day.day.day}',
        x - 6,
        baseline + 5,
        barWidth + 12,
        TextAlign.center,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    double x,
    double y,
    double width,
    TextAlign align,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: ink),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, Offset(x, y));
  }

  /// Un total en la unidad en que se lee: 2,3 M antes que 2.340.918.
  String _tokens(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    if (value >= 1000) return '${(value / 1000).round()} k';
    return '$value';
  }

  @override
  bool shouldRepaint(_UsageBarsPainter old) =>
      old.days != days || old.models != models;
}
