import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';
import 'package:keel_ui/src/modules/rules/ui/widget/rule_tile.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglas registradas'),
        actions: [
          IconButton(
            tooltip: 'Registrar nueva',
            icon: const Icon(Icons.add),
            onPressed: () => openRuleFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<RulesViewModel, RulesState>(
        viewmodel: RulesService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.rules.isEmpty) {
            return const Center(
              child: Text('Todavía no registraste ninguna regla.'),
            );
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
