import 'package:flutter/material.dart';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';

class RuleTile extends StatelessWidget {
  const RuleTile({super.key, required this.rule});

  final Rule rule;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await confirmWithCard(
      context,
      title: 'Eliminar regla',
      body:
          'Se eliminará la regla "${rule.name}". Los agentes que la tenían '
          'asignada dejarán de recibir sus instrucciones.',
      destructive: true,
    );

    if (confirmed) {
      RulesService.instance.notifier.deleteRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.rule,
      rule.name,
    );
    return ListTile(
      title: Text(rule.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rule.content, maxLines: 2, overflow: TextOverflow.ellipsis),
          _EnforcedBadge(ruleName: rule.name),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatalogLockButton(kind: CatalogLockKind.rule, name: rule.name),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: isLocked
                ? null
                : () => openRuleFormScreen(context, initial: rule),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: isLocked ? null : () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}

/// Si algún hook activo hace cumplir esta regla.
///
/// Es la respuesta visible a "¿esto se cumple, o se pide?": una regla sola
/// depende de que el modelo obedezca; con un hook detrás, no.
class _EnforcedBadge extends StatelessWidget {
  const _EnforcedBadge({required this.ruleName});

  final String ruleName;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<HooksViewModel, HooksState>(
      viewmodel: HooksService.instance.notifier,
      build: (state, viewmodel, keep) {
        final enforcing = state.hooks
            .where((hook) => hook.enabled && hook.enforces.contains(ruleName))
            .map((hook) => hook.name)
            .toList();
        if (enforcing.isEmpty) return const SizedBox.shrink();

        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, size: 14, color: colors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Garantizada por ${enforcing.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
