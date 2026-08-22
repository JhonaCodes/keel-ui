import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/project_form_screen.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/project_tile.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyectos'),
        actions: [
          IconButton(
            tooltip: 'Registrar nuevo',
            icon: const Icon(Icons.add),
            onPressed: () => openProjectFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<ProjectsViewModel, ProjectsState>(
        viewmodel: ProjectsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.projects.isEmpty) {
            return const Center(
              child: Text('Todavía no registraste ningún proyecto.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.projects.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                ProjectTile(project: state.projects[index]),
          );
        },
      ),
    );
  }
}
