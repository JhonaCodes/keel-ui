import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/ui/screen/requirement_form_screen.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';

/// Todos los requerimientos, incluidos los cerrados.
///
/// El sidebar muestra los que siguen abiertos porque es la columna de lo que
/// está pasando. Acá está la historia entera, que es lo que se consulta
/// cuando alguien pregunta "¿esto no lo habíamos pedido ya?".
class RequirementsScreen extends StatelessWidget {
  const RequirementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requerimientos internos'),
        actions: [
          IconButton(
            tooltip: 'Abrir uno',
            icon: const Icon(Icons.add),
            onPressed: () => openRequirementFormPanel(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<RequirementsViewModel, RequirementsState>(
        viewmodel: RequirementsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.requirements.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Todavía no hay ninguno. Aparecen cuando un proyecto '
                  'necesita algo de otro y lo pide.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.requirements.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _RequirementTile(requirement: state.requirements[index]),
          );
        },
      ),
    );
  }
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({required this.requirement});

  final InternalRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final projects = ProjectsService.instance.notifier.data.projects;
    String nameOf(String id) =>
        projects.where((project) => project.id == id).firstOrNull?.name ??
        'proyecto eliminado';

    return ListTile(
      isThreeLine: true,
      title: Text(
        '${requirement.code} · ${requirement.title}',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${nameOf(requirement.fromProjectId)} → '
            '#${nameOf(requirement.toProjectId)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            requirement.need,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Text(
        requirement.status.label.toLowerCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: requirement.status.isOpen
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
