import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';

class AgentProfileTile extends StatelessWidget {
  const AgentProfileTile({super.key, required this.profile});

  final AgentProfile profile;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar agente registrado'),
        content: Text(
          'Se eliminará el registro "${profile.name}". Esto no afecta a los '
          'chats que ya usaste con esta configuración.',
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
      AgentProfilesService.instance.notifier.deleteProfile(profile.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        profile.name,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
      ),
      isThreeLine: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.role.isNotEmpty) Text(profile.role),
          Text(
            '${modelLabelFor(profile.provider, profile.model)} · '
            '${effortLabel(profile.effort)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (profile.skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final skill in profile.skills)
                    Chip(
                      avatar: const Icon(Icons.extension_outlined, size: 16),
                      label: Text(
                        skill,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
          if (profile.rules.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final rule in profile.rules)
                    Chip(
                      avatar: const Icon(Icons.rule_outlined, size: 16),
                      label: Text(
                        rule,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                openAgentProfileFormScreen(context, initial: profile),
          ),
          IconButton(
            tooltip: 'Exportar como paquete',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () =>
                openBundleExportPanel(context, BundleKind.agent, profile.name),
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
