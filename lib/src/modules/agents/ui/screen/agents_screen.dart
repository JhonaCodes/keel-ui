import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/git_worktree/git_worktree.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profiles_screen.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/ui/view/agent_rail.dart';
import 'package:keel_ui/src/modules/boards/ui/screen/boards_screen.dart';
import 'package:keel_ui/src/modules/boards/ui/view/board_run_view.dart';
import 'package:keel_ui/src/modules/boards/ui/view/project_boards_view.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/machine/ui/screen/machine_screen.dart';
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
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/ui/view/requirement_thread_view.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/ui/view/projects_sidebar.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tools_screen.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflows_screen.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// El armazón: riel, sidebar y área central.
///
/// No guarda nada. Qué se ve lo dice [WorkspaceService] y esta pantalla lo
/// dibuja — antes tenía su propio `_focus`, que era la mitad de la verdad y
/// se desincronizaba de la otra mitad en cuanto algo tocaba la selección sin
/// pasar por acá.
class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReactiveViewModelBuilder<WorkspaceViewModel, WorkspaceState>(
        viewmodel: WorkspaceService.instance.notifier,
        build: (workspace, navigator, keepWorkspace) {
          return ReactiveViewModelBuilder<AgentsViewModel, AgentsState>(
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
                        onOpenSecrets: () => showFormPanel(
                          context,
                          child: const SecretsScreen(),
                        ),
                        onOpenMcpServers: () => showFormPanel(
                          context,
                          // Tampoco es un formulario: es un catálogo. En el ancho
                          // por defecto las fichas entran de a una por fila.
                          width: 1000,
                          child: const McpServersScreen(),
                        ),
                        onOpenKnowledge: () => showFormPanel(
                          context,
                          // Saber no es un formulario: es un navegador de dos
                          // columnas. En el ancho de panel por defecto el visor
                          // queda en una ranura de 280 puntos.
                          width: 1100,
                          child: const KnowledgeScreen(),
                        ),
                        onOpenWorkflows: () => showFormPanel(
                          context,
                          child: const WorkflowsScreen(),
                        ),
                        onOpenBoards: () => showFormPanel(
                          context,
                          width: 720,
                          child: BoardsScreen(onOpen: navigator.openBoard),
                        ),
                        onOpenMachine: () => showFormPanel(
                          context,
                          width: 820,
                          child: const MachineScreen(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      ProjectsSidebar(
                        state: projectsState,
                        workspace: workspace,
                        onNewProject: () => openProjectFormScreen(context),
                        onManageProjects: () => showFormPanel(
                          context,
                          child: const ProjectsScreen(),
                        ),
                        onManageAgents: () => showFormPanel(
                          context,
                          child: const AgentProfilesScreen(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _ConversationArea(
                          workspace: workspace,
                          agent: agentsState.selectedAgent,
                          project: projectsState.selectedProject,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// El área central: lo que el lente diga, y nada más.
///
/// `resolved` es la red: un tablero borrado deja un id apuntando a nada y la
/// vista cae en la lista sin que quien borró tenga que acordarse de avisar.
/// Lo mismo con una sesión cerrada, que [SessionChatView] ya resuelve sola.
class _ConversationArea extends StatelessWidget {
  const _ConversationArea({
    required this.workspace,
    required this.agent,
    required this.project,
  });

  final WorkspaceState workspace;
  final Agent? agent;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    if (workspace.lens == WorkspaceLens.requirement) {
      return ReactiveViewModelBuilder<RequirementsViewModel, RequirementsState>(
        viewmodel: RequirementsService.instance.notifier,
        build: (state, viewmodel, keep) {
          final requirement = state.selected;
          if (requirement == null) return const EmptyChatPlaceholder();
          return RequirementThreadView(
            key: ValueKey(requirement.id),
            requirement: requirement,
          );
        },
      );
    }

    final openProject = project;
    if (workspace.isProjectScoped && openProject != null) {
      final boardId = workspace.boardId;
      final lens = workspace.resolved(
        boardExists:
            boardId != null &&
            BoardsService.instance.notifier.boardById(boardId) != null,
      );
      // La franja del worktree va ARRIBA de las cuatro vistas y no adentro
      // de ninguna: dónde estás parado no es una pregunta del estado, ni del
      // tablero, ni de la sesión. Si el proyecto corre en el worktree
      // principal —lo normal— no ocupa nada.
      return Column(
        children: [
          WorktreeStrip(project: openProject),
          Expanded(
            child: switch (lens) {
              WorkspaceLens.projectState => ProjectStateView(
                key: ValueKey('estado-${openProject.id}'),
                project: openProject,
              ),
              WorkspaceLens.boards => ProjectBoardsView(
                key: ValueKey('tableros-${openProject.id}'),
                project: openProject,
              ),
              WorkspaceLens.board => BoardRunView(
                key: ValueKey(boardId),
                boardId: boardId!,
              ),
              // Sin ninguna abierta la vista muestra su propio vacío, con el
              // botón para abrir una. Ese caso ya lo sabía resolver.
              _ => SessionChatView(
                key: ValueKey(openProject.id),
                project: openProject,
              ),
            },
          ),
        ],
      );
    }

    final openAgent = agent;
    if (openAgent == null) return const EmptyChatPlaceholder();
    return ChatView(key: ValueKey(openAgent.id), agent: openAgent);
  }
}
