import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/use_agent_panel.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';
import 'package:keel_ui/src/modules/settings/ui/widget/settings_panel.dart';

/// Ancho de la columna entera — agentes arriba, registros abajo. Sale del
/// texto más largo que tiene que entrar con [_railLabelStyle], no al revés:
/// el rail es lo más angosto que puede ser sin cortar un nombre.
const _railWidth = 70.0;

/// La letra del rail es chica a propósito. Es lo que permite que el nombre
/// entre entero en 70 puntos: con la fuente por defecto haría falta casi el
/// doble de ancho para lo mismo, y el rail se comería el chat.
const _railLabelStyle = TextStyle(
  fontSize: 9,
  height: 1.2,
  fontWeight: FontWeight.w500,
);

class AgentRail extends StatelessWidget {
  const AgentRail({
    super.key,
    required this.state,
    required this.onSelectAgent,
    required this.onOpenProfiles,
    required this.onOpenSkills,
    required this.onOpenRules,
    required this.onOpenTools,
    required this.onOpenSecrets,
    required this.onOpenMcpServers,
    required this.onOpenKnowledge,
    required this.onOpenWorkflows,
  });

  final AgentsState state;
  final VoidCallback onSelectAgent;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSecrets;
  final VoidCallback onOpenMcpServers;
  final VoidCallback onOpenKnowledge;
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
          onOpenTools: onOpenTools,
          onOpenSecrets: onOpenSecrets,
          onOpenMcpServers: onOpenMcpServers,
          onOpenKnowledge: onOpenKnowledge,
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
    required this.onOpenTools,
    required this.onOpenSecrets,
    required this.onOpenMcpServers,
    required this.onOpenKnowledge,
    required this.onOpenWorkflows,
  });

  /// Letras que entran en [_railWidth] con [_railLabelStyle]. Lo que pasa se
  /// corta con puntos suspensivos: alcanza para reconocer de qué agente se
  /// trata, que es para lo que está.
  static const _maxLabelChars = 12;

  static String _shortName(String name) => name.length <= _maxLabelChars
      ? name
      : '${name.substring(0, _maxLabelChars - 1)}…';

  final AgentsState state;
  final String? keelAiProfileId;
  final VoidCallback onSelectAgent;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSecrets;
  final VoidCallback onOpenMcpServers;
  final VoidCallback onOpenKnowledge;
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
            labelType: NavigationRailLabelType.all,
            leading: SizedBox(
              width: _railWidth,
              child: Column(
                children: [
                  _RailButton(
                    label: 'Registrar',
                    icon: Icons.add_circle_outline,
                    tooltip: 'Registrar agente',
                    onPressed: () => openAgentProfileFormScreen(context),
                  ),
                  _RailButton(
                    label: 'Usar',
                    icon: Icons.person_search_outlined,
                    tooltip: 'Usar un agente registrado',
                    onPressed: () {
                      onSelectAgent();
                      openUseAgentPanel(context);
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ),
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
                  label: Text(
                    _shortName(agent.name),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: _railLabelStyle,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: _railWidth,
          child: _RegistryButtons(
            onOpenProfiles: onOpenProfiles,
            onOpenSkills: onOpenSkills,
            onOpenRules: onOpenRules,
            onOpenTools: onOpenTools,
            onOpenSecrets: onOpenSecrets,
            onOpenMcpServers: onOpenMcpServers,
            onOpenKnowledge: onOpenKnowledge,
            onOpenWorkflows: onOpenWorkflows,
          ),
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
    required this.onOpenTools,
    required this.onOpenSecrets,
    required this.onOpenMcpServers,
    required this.onOpenKnowledge,
    required this.onOpenWorkflows,
  });

  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSecrets;
  final VoidCallback onOpenMcpServers;
  final VoidCallback onOpenKnowledge;
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
          // Orden por uso real, no por jerarquía del modelo. Arriba lo que
          // se abre todos los días; abajo lo que se configura una vez y se
          // deja quieto. El hueco del medio marca el corte entre los dos
          // grupos sin gastar una línea más.
          _RailButton(
            label: 'Asistente',
            icon: Icons.auto_awesome,
            onPressed: () => AssistantWindowBridge.instance.open(),
          ),
          _RailButton(
            label: 'Agentes',
            icon: Icons.badge_outlined,
            onPressed: onOpenProfiles,
          ),
          _RailButton(
            label: 'Skills',
            icon: Icons.extension_outlined,
            onPressed: onOpenSkills,
          ),
          _RailButton(
            label: 'Workflows',
            icon: Icons.account_tree_outlined,
            onPressed: onOpenWorkflows,
          ),
          _RailButton(
            label: 'Reglas',
            icon: Icons.rule_outlined,
            onPressed: onOpenRules,
          ),
          const SizedBox(height: 12),
          _RailButton(
            label: 'Tools',
            icon: Icons.terminal_outlined,
            onPressed: onOpenTools,
          ),
          _RailButton(
            label: 'MCP',
            icon: Icons.hub_outlined,
            tooltip: 'Integraciones MCP',
            onPressed: onOpenMcpServers,
          ),
          _RailButton(
            label: 'Saber',
            icon: Icons.menu_book_outlined,
            tooltip: 'Conocimiento',
            onPressed: onOpenKnowledge,
          ),
          _RailButton(
            label: 'Secrets',
            icon: Icons.key_outlined,
            onPressed: onOpenSecrets,
          ),
          _RailButton(
            label: 'Ajustes',
            icon: Icons.settings_outlined,
            tooltip: 'Configuración',
            onPressed: () => openSettingsPanel(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Un registro del rail: icono con su nombre debajo.
///
/// Con tooltip solo, saber a dónde lleva cada uno de los diez iconos obliga
/// a pasar el mouse por todos. El nombre escrito lo resuelve de una mirada;
/// el tooltip queda para el nombre largo cuando [tooltip] difiere del
/// [label] corto que entra en el ancho del rail.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip ?? label,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: _railLabelStyle.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
