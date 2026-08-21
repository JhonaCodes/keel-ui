import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/agents/model/claude_model_option.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

Future<void> openUseAgentPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const UseAgentPanel());
}

/// Picks one of the registered agents to talk to on its own. Agents are
/// registered once and reused everywhere — in a station, in a workflow step,
/// or here as a 1:1 chat — so this panel never creates a new identity, it
/// only opens a conversation with one that already exists.
class UseAgentPanel extends StatefulWidget {
  const UseAgentPanel({super.key});

  @override
  State<UseAgentPanel> createState() => _UseAgentPanelState();
}

class _UseAgentPanelState extends State<UseAgentPanel> {
  bool _fullFileSystemAccess = false;

  void _use(AgentProfile profile) {
    AgentsService.instance.notifier.createAgent(
      profile.name,
      model: profile.model,
      fullFileSystemAccess: _fullFileSystemAccess,
      effort: profile.effort,
      profileId: profile.id,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usar un agente'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextButton.icon(
              onPressed: () => openAgentProfileFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar'),
            ),
          ),
        ],
      ),
      body:
          ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
            viewmodel: AgentProfilesService.instance.notifier,
            build: (state, viewmodel, keep) {
              // Keel AI is reached through the dedicated "Asistente" button,
              // never through this generic picker — starting it from here
              // would bypass its own session tracking and welcome card.
              final profiles = state.profiles
                  .where((profile) => profile.name != kKeelAiHandle)
                  .toList();
              if (profiles.isEmpty) return const _NoRegisteredAgents();

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _PermissionToggle(
                    value: _fullFileSystemAccess,
                    onChanged: (value) =>
                        setState(() => _fullFileSystemAccess = value),
                  ),
                  const Divider(height: 1),
                  for (final profile in profiles)
                    _ProfileRow(profile: profile, onUse: () => _use(profile)),
                ],
              );
            },
          ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Acceso a todo el sistema de archivos'),
      subtitle: const Text(
        'Se decide acá, no en el registro: el mismo agente puede tener más o '
        'menos permiso según dónde lo uses.',
      ),
      onChanged: (enabled) => onChanged(enabled ?? false),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile, required this.onUse});

  final AgentProfile profile;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onUse,
      title: Text(
        profile.name,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(
        [
          if (profile.role.isNotEmpty) profile.role,
          claudeModelLabel(profile.model),
          effortLabel(profile.effort),
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Icon(Icons.arrow_forward, size: 18, color: scheme.primary),
    );
  }
}

class _NoRegisteredAgents extends StatelessWidget {
  const _NoRegisteredAgents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Todavía no registraste ningún agente',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Registrá uno y queda disponible en todos lados: para hablarle '
              'directo, para sumarlo a una estación y para que un paso de '
              'workflow lo busque por su rol.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openAgentProfileFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar agente'),
            ),
          ],
        ),
      ),
    );
  }
}
