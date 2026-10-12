import 'package:flutter/material.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_ui/src/modules/machine/model/plan_usage_labels.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/machine_metric.dart';

/// Una cuenta: quién es, si es la que usan los turnos, cuánto lleva de cada
/// límite, y las acciones sobre su sesión.
///
/// Las acciones son opcionales: sin ellas la tarjeta solo muestra.
class PlanAccountUsage extends StatelessWidget {
  const PlanAccountUsage({
    super.key,
    required this.usage,
    this.active = false,
    this.busy = false,
    this.onUse,
    this.onSignIn,
    this.onSignOut,
    this.onRemove,
  });

  final PlanUsage usage;

  /// Es la cuenta con la que corren los turnos de su proveedor.
  final bool active;

  /// Hay una acción en curso sobre esta cuenta.
  final bool busy;

  /// Null cuando el proveedor no tiene cuentas para elegir (OpenRouter).
  final VoidCallback? onUse;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;

  /// Null para la cuenta por defecto, que no se quita.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final who = usage.identity;
    final signedOut = usage.problem == PlanUsageProblem.notSignedIn;
    final spend = PlanUsageLabels.spend(usage.spend);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onUse case final use?)
                Tooltip(
                  message: active
                      ? 'Los turnos de ${usage.account.provider.label} usan esta cuenta'
                      : 'Usar esta cuenta en los turnos',
                  child: Checkbox(
                    value: active,
                    visualDensity: VisualDensity.compact,
                    // Marcada y habilitada: gris parecería apagada. Tocar la
                    // que ya está en uso no hace nada.
                    onChanged: busy
                        ? null
                        : (_) {
                            if (!active) use();
                          },
                  ),
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: usage.account.provider.hasAccounts
                            ? usage.account.name
                            : 'clave de la bóveda',
                      ),
                      if (active)
                        TextSpan(
                          text: '  en uso',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.tertiary,
                          ),
                        ),
                      TextSpan(
                        text: who.isEmpty ? '' : '  $who',
                        style: TextStyle(fontSize: 11, color: scheme.outline),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              else ...[
                if (onSignIn case final signIn?)
                  _Action(
                    label: signedOut ? 'Iniciar sesión' : 'Volver a entrar',
                    onPressed: signIn,
                    emphasized: signedOut,
                  ),
                if (onSignOut case final signOut? when !signedOut)
                  _Action(label: 'Cerrar sesión', onPressed: signOut),
                if (onRemove case final remove?)
                  _Action(label: 'Quitar', onPressed: remove),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (!usage.ok)
            Text(
              PlanUsageLabels.problem(usage),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.outline),
            )
          else ...[
            Row(
              children: [
                for (final (index, meter) in usage.meters.indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(
                    child: MachineMetric(
                      label: PlanUsageLabels.meter(meter.kind),
                      value: PlanUsageLabels.percent(meter.percent),
                      detail: PlanUsageLabels.detail(meter),
                      ratio: PlanUsageLabels.ratio(meter.percent),
                      barColor: PlanUsageLabels.levelColor(meter.level, scheme),
                    ),
                  ),
                ],
              ],
            ),
            if (spend.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Gasto: $spend',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    // El tamaño va en el Text y no en el estilo del botón: ahí reemplazaría
    // la tipografía del tema en vez de sumarse a ella.
    final text = Text(label, style: const TextStyle(fontSize: 11.5));
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: emphasized
          ? FilledButton.tonal(onPressed: onPressed, style: style, child: text)
          : TextButton(onPressed: onPressed, style: style, child: text),
    );
  }
}
