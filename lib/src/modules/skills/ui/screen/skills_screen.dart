import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skill_form_screen.dart';
import 'package:keel_ui/src/modules/skills/ui/widget/skill_tile.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills registrados'),
        actions: [
          IconButton(
            tooltip: 'Registrar nuevo',
            icon: const Icon(Icons.add),
            onPressed: () => openSkillFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<SkillsViewModel, SkillsState>(
        viewmodel: SkillsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.skills.isEmpty) {
            return const Center(
              child: Text('Todavía no registraste ningún skill.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.skills.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                SkillTile(skill: state.skills[index]),
          );
        },
      ),
    );
  }
}
