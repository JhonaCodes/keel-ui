import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/use_agent_panel.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/assistant/ui/widget/assistant_panel.dart';
import 'package:keel_ui/src/modules/settings/ui/widget/settings_panel.dart';

class AgentRail extends StatelessWidget {
  const AgentRail({
    super.key,
    required this.state,
    required this.onSelectAgent,
    required this.onOpenProfiles,
    required this.onOpenSkills,
    required this.onOpenRules,
    required this.onOpenWorkflows,
  });

  final AgentsState state;
  final VoidCallback onSelectAgent;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenWorkflows;

  @override
  Widget build(BuildContext context) {
    // Subscribed, not read off the singleton: this decides which agents the
    // rail lists, and the profile catalogue loads asynchronously.
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (profilesState, profilesViewModel, keep) {
        final keelAiProfileId = profilesState.profiles
            .where((profile) => profile.name == kKeelAiHandle)
            .firstOrNull
            ?.id;
        return _AgentRailContent(
          state: state,
          keelAiProfileId: keelAiProfileId,
          onSelectAgent: onSelectAgent,
          onOpenProfiles: onOpenProfiles,
          onOpenSkills: onOpenSkills,
          onOpenRules: onOpenRules,
          onOpenWorkflows: onOpenWorkflows,
        );
      },
    );
  }
}

class _AgentRailContent extends StatelessWidget {
  const _AgentRailContent({
    required this.state,
    required this.keelAiProfileId,
    required this.onSelectAgent,
    required this.onOpenProfiles,
    required this.onOpenSkills,
    required this.onOpenRules,
    required this.onOpenWorkflows,
  });

  /// The rail stays narrow and icon-only; the names live in the stations
  /// column instead. Material's default is wider, so it is pinned here.
  static const _railWidth = 58.0;

  final AgentsState state;
  final String? keelAiProfileId;
  final VoidCallback onSelectAgent;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenWorkflows;

  @override
  Widget build(BuildContext context) {
    // Keel AI's own sessions live behind the "Asistente" button, not mixed
    // in here with the agents the user registered. Guarded on non-null: an
    // unresolved keelAiProfileId must not be mistaken for "hide every agent
    // with no profile" — plenty of ordinary agents have `profileId == null`.
    final keelAiId = keelAiProfileId;
    final agents = keelAiId == null
        ? state.agents
        : state.agents.where((agent) => agent.profileId != keelAiId).toList();
    final selectedIndex = agents.indexWhere(
      (agent) => agent.id == state.selectedAgentId,
    );

    // The registry buttons live outside the NavigationRail on purpose: the
    // rail lays its own children out inside a scroll view, so anything in
    // `trailing` stops receiving taps once the column outgrows the viewport.
    return Column(
      children: [
        Expanded(
          child: NavigationRail(
            minWidth: _railWidth,
            selectedIndex: selectedIndex < 0 ? null : selectedIndex,
            onDestinationSelected: (index) {
              onSelectAgent();
              AgentsService.instance.notifier.selectAgent(agents[index].id);
            },
            labelType: NavigationRailLabelType.none,
            leading: Column(
              children: [
                IconButton(
                  tooltip: 'Registrar agente',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => openAgentProfileFormScreen(context),
                ),
                IconButton(
                  tooltip: 'Usar un agente registrado',
                  icon: const Icon(Icons.person_search_outlined),
                  onPressed: () {
                    onSelectAgent();
                    openUseAgentPanel(context);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
            destinations: [
              for (final agent in agents)
                NavigationRailDestination(
                  icon: AgentStatusIcon(
                    color: agent.iconColor,
                    selected: false,
                    isWorking: agent.isStreaming,
                    contextRatio: agent.contextUsageRatio,
                  ),
                  selectedIcon: AgentStatusIcon(
                    color: agent.iconColor,
                    selected: true,
                    isWorking: agent.isStreaming,
                    contextRatio: agent.contextUsageRatio,
                  ),
                  label: Text(agent.name, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
        _RegistryButtons(
          onOpenProfiles: onOpenProfiles,
          onOpenSkills: onOpenSkills,
          onOpenRules: onOpenRules,
          onOpenWorkflows: onOpenWorkflows,
        ),
      ],
    );
  }
}

class _RegistryButtons extends StatelessWidget {
  const _RegistryButtons({
    required this.onOpenProfiles,
    required this.onOpenSkills,
    required this.onOpenRules,
    required this.onOpenWorkflows,
  });

  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenWorkflows;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 4),
          IconButton(
            tooltip: 'Asistente',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => openAssistantPanel(context),
          ),
          IconButton(
            tooltip: 'Agentes registrados',
            icon: const Icon(Icons.badge_outlined),
            onPressed: onOpenProfiles,
          ),
          IconButton(
            tooltip: 'Skills registrados',
            icon: const Icon(Icons.extension_outlined),
            onPressed: onOpenSkills,
          ),
          IconButton(
            tooltip: 'Reglas registradas',
            icon: const Icon(Icons.rule_outlined),
            onPressed: onOpenRules,
          ),
          IconButton(
            tooltip: 'Workflows registrados',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: onOpenWorkflows,
          ),
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openSettingsPanel(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
