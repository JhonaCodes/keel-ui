import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_ui/src/modules/machine/model/plan_accounts_state.dart';
import 'package:keel_ui/src/modules/machine/model/plan_usage_labels.dart';
import 'package:keel_ui/src/modules/machine/viewmodel/plan_accounts_viewmodel.dart';

/// El consumo de todas las cuentas, siempre a la vista en el riel, por
/// proveedor: S = sesión, W = semana, $ = créditos. La cuenta en uso va
/// primero, con un punto y en color. Un proveedor con varias cuentas se
/// pliega tocando su nombre y queda solo la en uso. Un clic en una cuenta
/// abre Máquina, donde se elige cuál usar y se inicia sesión.
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
                  foldable: state.hasSeveral(group.provider),
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

/// Un proveedor en el riel: su nombre (que pliega) y sus cuentas.
class PlanUsageRailProvider extends StatelessWidget {
  const PlanUsageRailProvider({
    super.key,
    required this.provider,
    required this.expanded,
    required this.foldable,
    required this.accounts,
    required this.isActive,
    required this.onToggle,
    required this.onPressed,
  });

  final PlanProvider provider;
  final bool expanded;

  /// Solo un proveedor con varias cuentas tiene algo que plegar.
  final bool foldable;
  final List<PlanUsage> accounts;
  final bool Function(PlanAccount account) isActive;
  final VoidCallback onToggle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: foldable
                ? (expanded
                      ? 'Plegar: dejar solo la cuenta en uso'
                      : 'Ver todas las cuentas de ${provider.label}')
                : provider.label,
            waitDuration: const Duration(milliseconds: 400),
            child: InkWell(
              onTap: foldable ? onToggle : onPressed,
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
                  if (foldable)
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
              showName: provider.hasAccounts,
              onPressed: onPressed,
            ),
        ],
      ),
    );
  }
}

/// Una cuenta en el riel: su nombre (con punto si es la en uso) y una
/// barrita por límite.
class PlanUsageRailAccount extends StatelessWidget {
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

  /// OpenRouter tiene una sola clave: su nombre no dice nada.
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
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          decoration: BoxDecoration(
            color: active ? scheme.primary.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showName)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (active) ...[
                      Icon(Icons.circle, size: 5, color: scheme.primary),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        usage.account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: active ? scheme.primary : scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 1),
              if (usage.ok)
                for (final meter in usage.meters) _RailMeter(meter: meter)
              else
                Icon(Icons.login, size: 12, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailMeter extends StatelessWidget {
  const _RailMeter({required this.meter});

  final PlanMeter meter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(
      fontFamily: 'monospace',
      fontSize: 8.5,
      height: 1.3,
      color: scheme.outline,
    );
    return Row(
      children: [
        Text(PlanUsageLabels.meterShort(meter.kind), style: small),
        const SizedBox(width: 3),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: LinearProgressIndicator(
              value: PlanUsageLabels.ratio(meter.percent) ?? 0,
              minHeight: 3,
              backgroundColor: scheme.outlineVariant,
              color: PlanUsageLabels.levelColor(meter.level, scheme),
            ),
          ),
        ),
        const SizedBox(width: 3),
        SizedBox(
          width: 15,
          child: Text(
            PlanUsageLabels.shortPercent(meter.percent),
            textAlign: TextAlign.right,
            style: small.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
