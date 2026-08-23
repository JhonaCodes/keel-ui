import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skill_form_screen.dart';

class SkillTile extends StatelessWidget {
  const SkillTile({super.key, required this.skill});

  final Skill skill;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar skill'),
        content: Text(
          'Se eliminará el skill "${skill.name}". Los agentes que lo tenían '
          'asignado dejarán de recibir sus instrucciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      SkillsService.instance.notifier.deleteSkill(skill.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: skill.isGlobal
          ? const Tooltip(
              message: 'Global: la reciben todos los agentes',
              child: Chip(
                label: Text('global'),
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
      title: Text(skill.name),
      subtitle: Text(
        skill.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openSkillFormScreen(context, initial: skill),
          ),
          IconButton(
            tooltip: 'Exportar como paquete',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () =>
                openBundleExportPanel(context, BundleKind.skill, skill.name),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
