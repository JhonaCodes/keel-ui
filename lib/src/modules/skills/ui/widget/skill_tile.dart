import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skill_form_screen.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';

class SkillTile extends StatelessWidget {
  const SkillTile({super.key, required this.skill});

  final Skill skill;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await confirmWithCard(
      context,
      title: 'Eliminar skill',
      body:
          'Se eliminará el skill "${skill.name}". Los agentes que lo tenían '
          'asignado dejarán de recibir sus instrucciones.',
      destructive: true,
    );

    if (confirmed) {
      SkillsService.instance.notifier.deleteSkill(skill.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.skill,
      skill.name,
    );
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
          CatalogLockButton(kind: CatalogLockKind.skill, name: skill.name),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: isLocked
                ? null
                : () => openSkillFormScreen(context, initial: skill),
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
            onPressed: isLocked ? null : () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
