import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_ui/src/modules/machine/model/plan_accounts_state.dart';
import 'package:keel_ui/src/modules/machine/model/plan_usage_labels.dart';
import 'package:keel_ui/src/modules/machine/viewmodel/plan_accounts_viewmodel.dart';

/// El consumo de todas las cuentas, a la vista en el riel, por proveedor:
/// S = sesión, W = semana, $ = créditos, K = tope de la clave. La cuenta en
/// uso va primero, con el tile en color. Todo proveedor se pliega tocando
/// su nombre, y plegado queda solo el nombre. Un clic en una cuenta abre
/// Máquina, donde se elige cuál usar y se inicia sesión.
class PlanUsageRail extends StatelessWidget {
  const PlanUsageRail({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<PlanAccountsViewModel, PlanAccountsState>(
      viewmodel: PlanAccountsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final rail = state.rail;
        if (rail.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
          child: Column(
            children: [
              for (final group in rail)
                PlanUsageRailProvider(
                  provider: group.provider,
                  expanded: group.expanded,
                  accounts: group.accounts,
                  isActive: state.isActive,
                  onToggle: () => viewmodel.toggleRail(group.provider),
                  onPressed: onPressed,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Un proveedor en el riel: su nombre con la flecha que lo pliega, y debajo
/// sus cuentas, todas a la misma distancia.
class PlanUsageRailProvider extends StatelessWidget {
  const PlanUsageRailProvider({
    super.key,
    required this.provider,
    required this.expanded,
    required this.accounts,
    required this.isActive,
    required this.onToggle,
    required this.onPressed,
  });

  final PlanProvider provider;
  final bool expanded;
  final List<PlanUsage> accounts;
  final bool Function(PlanAccount account) isActive;
  final VoidCallback onToggle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: expanded
                ? 'Plegar ${provider.label}'
                : 'Ver las cuentas de ${provider.label}',
            waitDuration: const Duration(milliseconds: 400),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      PlanUsageLabels.providerShort(provider),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 12,
                    color: scheme.outline,
                  ),
                ],
              ),
            ),
          ),
          for (final usage in accounts)
            PlanUsageRailAccount(
              usage: usage,
              active: isActive(usage.account),
              // La por defecto no lleva nombre: «default» no dice nada, y si
              // está en uso ya lo dice el color del tile. OpenRouter tiene
              // una sola clave.
              showName: provider.hasAccounts && !usage.account.isDefault,
              onPressed: onPressed,
            ),
        ],
      ),
    );
  }
}

/// Una cuenta en el riel, como un tile: su nombre (si no es la por defecto)
/// y un anillo por límite, con el número adentro y la letra abajo. El
/// número tiene todo el ancho del anillo, así que tres cifras entran en una
/// línea; antes iba al lado de una barra, en quince puntos, y se partía.
class PlanUsageRailAccount extends StatelessWidget {
  /// Todas las cuentas miden lo mismo, tengan nombre o no: el riel se lee
  /// como una columna pareja.
  static const tileHeight = 54.0;

  const PlanUsageRailAccount({
    super.key,
    required this.usage,
    required this.onPressed,
    this.active = false,
    this.showName = true,
  });

  final PlanUsage usage;
  final VoidCallback onPressed;

  /// Es la cuenta con la que corren los turnos de su proveedor.
  final bool active;

  /// Si el nombre dice algo: no en la cuenta por defecto ni en la única
  /// clave de OpenRouter.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: [
        if (active) 'En uso',
        PlanUsageLabels.summary(usage),
      ].join(' · '),
      waitDuration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: tileHeight,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary.withValues(alpha: 0.10)
                  : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? scheme.primary.withValues(alpha: 0.35)
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showName) ...[
                  Text(
                    usage.account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active ? scheme.primary : scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Una sola fila, que se achica si un día hay más límites de
                // los que entran: partirla en dos cambiaría el alto.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      for (final meter in usage.meters)
                        _RailGauge(meter: meter),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un límite: el anillo lleno hasta el consumo, el número adentro y la letra
/// del límite abajo. Pasado el 100 % el anillo queda lleno y en rojo, y el
/// número dice cuánto se pasó.
class _RailGauge extends StatelessWidget {
  const _RailGauge({required this.meter});

  static const _size = 24.0;
  static const _stroke = 2.5;

  final PlanMeter meter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: _size,
          child: CustomPaint(
            painter: _RingPainter(
              ratio: PlanUsageLabels.ratio(meter.percent) ?? 0,
              stroke: _stroke,
              track: scheme.outlineVariant,
              fill: PlanUsageLabels.levelColor(meter.level, scheme),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_stroke + 1.5),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    PlanUsageLabels.shortPercent(meter.percent),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          PlanUsageLabels.meterShort(meter.kind),
          style: TextStyle(
            fontSize: 7.5,
            height: 1.1,
            fontWeight: FontWeight.w500,
            color: scheme.outline,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.ratio,
    required this.stroke,
    required this.track,
    required this.fill,
  });

  final double ratio;
  final double stroke;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(arc, paint..color = track);
    if (ratio <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      paint
        ..color = fill
        ..strokeCap = ratio >= 1 ? StrokeCap.butt : StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio ||
      old.stroke != stroke ||
      old.track != track ||
      old.fill != fill;
}
