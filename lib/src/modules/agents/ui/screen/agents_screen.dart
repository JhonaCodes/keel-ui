import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profiles_screen.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/ui/view/agent_rail.dart';
import 'package:keel_ui/src/modules/agents/ui/view/chat_view.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/empty_chat_placeholder.dart';
import 'package:keel_ui/src/modules/hooks/ui/screen/hooks_screen.dart';
import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_screen.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_servers_screen.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rules_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secrets_screen.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skills_screen.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/project_form_screen.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/projects_screen.dart';
import 'package:keel_ui/src/modules/projects/ui/view/project_state_view.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/ui/view/projects_sidebar.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tools_screen.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflows_screen.dart';

/// Which conversation the content area shows: a 1:1 agent chat or a project
/// channel. Registries and forms never take the content area over — they open
/// as a side panel, so the conversation stays on screen behind them.
enum _Focus { agent, project }

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  _Focus _focus = _Focus.agent;

  void _focusAgent() => setState(() => _focus = _Focus.agent);

  void _focusProject(String projectId) {
    ProjectsService.instance.notifier.selectProject(projectId);
    setState(() => _focus = _Focus.project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReactiveViewModelBuilder<AgentsViewModel, AgentsState>(
        viewmodel: AgentsService.instance.notifier,
        build: (agentsState, agentsViewModel, keepAgents) {
          return ReactiveViewModelBuilder<ProjectsViewModel, ProjectsState>(
            viewmodel: ProjectsService.instance.notifier,
            build: (projectsState, projectsViewModel, keepProjects) {
              return Row(
                children: [
                  AgentRail(
                    onOpenProfiles: () => showFormPanel(
                      context,
                      child: const AgentProfilesScreen(),
                    ),
                    onOpenSkills: () =>
                        showFormPanel(context, child: const SkillsScreen()),
                    onOpenRules: () =>
                        showFormPanel(context, child: const RulesScreen()),
                    onOpenHooks: () =>
                        showFormPanel(context, child: const HooksScreen()),
                    onOpenTools: () =>
                        showFormPanel(context, child: const ToolsScreen()),
                    onOpenSecrets: () =>
                        showFormPanel(context, child: const SecretsScreen()),
                    onOpenMcpServers: () =>
                        showFormPanel(context, child: const McpServersScreen()),
                    onOpenKnowledge: () => showFormPanel(
                      context,
                      // Saber no es un formulario: es un navegador de dos
                      // columnas. En el ancho de panel por defecto el visor
                      // queda en una ranura de 280 puntos.
                      width: 1100,
                      child: const KnowledgeScreen(),
                    ),
                    onOpenWorkflows: () =>
                        showFormPanel(context, child: const WorkflowsScreen()),
                  ),
                  const VerticalDivider(width: 1),
                  ProjectsSidebar(
                    state: projectsState,
                    projectFocused: _focus == _Focus.project,
                    onSelectProject: _focusProject,
                    onSelectAgent: (agentId) {
                      AgentsService.instance.notifier.selectAgent(agentId);
                      _focusAgent();
                    },
                    onNewProject: () => openProjectFormScreen(context),
                    onManageProjects: () =>
                        showFormPanel(context, child: const ProjectsScreen()),
                    onManageAgents: () => showFormPanel(
                      context,
                      child: const AgentProfilesScreen(),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _ConversationArea(
                      focus: _focus,
                      agent: agentsState.selectedAgent,
                      project: projectsState.selectedProject,
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
    required this.project,
  });

  final _Focus focus;
  final Agent? agent;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final openProject = project;
    if (focus == _Focus.project && openProject != null) {
      // Sin sesión abierta se ve el ESTADO del proyecto. No hace falta un
      // campo que lo diga: "ninguna sesión abierta" y "estoy mirando cómo va
      // el proyecto" son la misma situación.
      if (openProject.activeSession == null) {
        return ProjectStateView(
          key: ValueKey('estado-${openProject.id}'),
          project: openProject,
        );
      }
      return SessionChatView(
        key: ValueKey(openProject.id),
        project: openProject,
      );
    }

    final openAgent = agent;
    if (openAgent == null) return const EmptyChatPlaceholder();
    return ChatView(key: ValueKey(openAgent.id), agent: openAgent);
  }
}
