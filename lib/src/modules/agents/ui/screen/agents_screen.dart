import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profiles_screen.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/ui/view/agent_rail.dart';
import 'package:keel_ui/src/modules/agents/ui/view/chat_view.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/empty_chat_placeholder.dart';
import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_screen.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_servers_screen.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rules_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secrets_screen.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skills_screen.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/ui/screen/station_form_screen.dart';
import 'package:keel_ui/src/modules/stations/ui/screen/stations_screen.dart';
import 'package:keel_ui/src/modules/stations/ui/view/station_chat_view.dart';
import 'package:keel_ui/src/modules/stations/ui/view/stations_sidebar.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tools_screen.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflows_screen.dart';

/// Which conversation the content area shows: a 1:1 agent chat or a station
/// channel. Registries and forms never take the content area over — they open
/// as a side panel, so the conversation stays on screen behind them.
enum _Focus { agent, station }

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  _Focus _focus = _Focus.agent;

  void _focusAgent() => setState(() => _focus = _Focus.agent);

  void _focusStation(String stationId) {
    StationsService.instance.notifier.selectStation(stationId);
    setState(() => _focus = _Focus.station);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReactiveViewModelBuilder<AgentsViewModel, AgentsState>(
        viewmodel: AgentsService.instance.notifier,
        build: (agentsState, agentsViewModel, keepAgents) {
          return ReactiveViewModelBuilder<StationsViewModel, StationsState>(
            viewmodel: StationsService.instance.notifier,
            build: (stationsState, stationsViewModel, keepStations) {
              return Row(
                children: [
                  AgentRail(
                    state: agentsState,
                    onSelectAgent: _focusAgent,
                    onOpenProfiles: () => showFormPanel(
                      context,
                      child: const AgentProfilesScreen(),
                    ),
                    onOpenSkills: () =>
                        showFormPanel(context, child: const SkillsScreen()),
                    onOpenRules: () =>
                        showFormPanel(context, child: const RulesScreen()),
                    onOpenTools: () =>
                        showFormPanel(context, child: const ToolsScreen()),
                    onOpenSecrets: () =>
                        showFormPanel(context, child: const SecretsScreen()),
                    onOpenMcpServers: () => showFormPanel(
                      context,
                      child: const McpServersScreen(),
                    ),
                    onOpenKnowledge: () => showFormPanel(
                      context,
                      child: const KnowledgeScreen(),
                    ),
                    onOpenWorkflows: () =>
                        showFormPanel(context, child: const WorkflowsScreen()),
                  ),
                  const VerticalDivider(width: 1),
                  StationsSidebar(
                    state: stationsState,
                    stationFocused: _focus == _Focus.station,
                    onSelectStation: _focusStation,
                    onSelectAgent: (agentId) {
                      AgentsService.instance.notifier.selectAgent(agentId);
                      _focusAgent();
                    },
                    onNewStation: () => openStationFormScreen(context),
                    onManageStations: () =>
                        showFormPanel(context, child: const StationsScreen()),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _ConversationArea(
                      focus: _focus,
                      agent: agentsState.selectedAgent,
                      station: stationsState.selectedStation,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The content area: whichever conversation currently has focus.
class _ConversationArea extends StatelessWidget {
  const _ConversationArea({
    required this.focus,
    required this.agent,
    required this.station,
  });

  final _Focus focus;
  final Agent? agent;
  final Station? station;

  @override
  Widget build(BuildContext context) {
    final openStation = station;
    if (focus == _Focus.station && openStation != null) {
      return StationChatView(
        key: ValueKey(openStation.id),
        station: openStation,
      );
    }

    final openAgent = agent;
    if (openAgent == null) return const EmptyChatPlaceholder();
    return ChatView(key: ValueKey(openAgent.id), agent: openAgent);
  }
}
