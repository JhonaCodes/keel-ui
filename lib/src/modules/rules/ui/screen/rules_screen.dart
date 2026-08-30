import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';
import 'package:keel_ui/src/modules/rules/ui/widget/rule_tile.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitleRulesRegistered),
        actions: [
          IconButton(
            tooltip: t.tooltipRegisterNew,
            icon: const Icon(Icons.add),
            onPressed: () => openRuleFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<RulesViewModel, RulesState>(
        viewmodel: RulesService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.rules.isEmpty) {
            return Center(child: Text(t.messageNoRulesRegistered));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.rules.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => RuleTile(rule: state.rules[index]),
          );
        },
      ),
    );
  }
}
