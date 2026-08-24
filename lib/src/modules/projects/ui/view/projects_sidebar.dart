import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/core/ui/inline_rename_field.dart';
import 'package:keel_ui/src/core/ui/sidebar_section_row.dart';
import 'package:keel_ui/src/modules/requirements/ui/screen/requirement_form_screen.dart';
import 'package:keel_ui/src/modules/requirements/ui/screen/requirements_screen.dart';
import 'package:keel_ui/src/modules/requirements/ui/widget/requirements_group.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/use_agent_panel.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/boards/ui/widget/boards_group.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_plan_list.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// La lista de canales: proyectos y, bajo el seleccionado, sus tres
/// secciones —Estado, Tableros y Sesiones— al mismo nivel y escritas igual.
///
/// No decide nada de navegación: cada fila le pide a [WorkspaceViewModel] que
/// abra algo, y el área central dibuja lo que ese lente diga. Antes la fila
/// movía la selección por su cuenta y la pantalla tenía su propio `_focus`,
/// así que tocar una sesión con un tablero abierto no llevaba a ninguna
/// parte.
class ProjectsSidebar extends StatelessWidget {
  const ProjectsSidebar({
    super.key,
    required this.state,
    required this.workspace,
    required this.onNewProject,
    required this.onManageProjects,
    required this.onManageAgents,
  });

  final ProjectsState state;
  final WorkspaceState workspace;
  final VoidCallback onNewProject;
  final VoidCallback onManageProjects;
  final VoidCallback onManageAgents;

  @override
  Widget build(BuildContext context) {
    // Subscribed, not read off the singleton: the workflow catalogue loads
    // asynchronously, and the session counters need to appear when it lands.
    return ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
      viewmodel: WorkflowsService.instance.notifier,
      build: (workflowsState, viewmodel, keep) => _SidebarList(
        state: state,
        workspace: workspace,
        onNewProject: onNewProject,
        onManageProjects: onManageProjects,
        onManageAgents: onManageAgents,
      ),
    );
  }
}

class _SidebarList extends StatefulWidget {
  const _SidebarList({
    required this.state,
    required this.workspace,
    required this.onNewProject,
    required this.onManageProjects,
    required this.onManageAgents,
  });

  final ProjectsState state;
  final WorkspaceState workspace;
  final VoidCallback onNewProject;
  final VoidCallback onManageProjects;
  final VoidCallback onManageAgents;

  @override
  State<_SidebarList> createState() => _SidebarListState();
}

class _SidebarListState extends State<_SidebarList> {
  /// Si las listas de cada sección están abiertas. Vive acá y no en el
  /// ViewModel porque es de esta ventana: cuánto menú querés ver no es un
  /// dato del sistema. Una sola por sección y no una por proyecto —hay un
  /// solo proyecto abierto a la vez.
  bool _boardsOpen = true;
  bool _sessionsOpen = true;

  ProjectsState get state => widget.state;
  WorkspaceState get workspace => widget.workspace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final navigator = WorkspaceService.instance.notifier;

    return Container(
      width: 210,
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          _GroupHead(
            label: 'Proyectos',
            onAdd: widget.onNewProject,
            onManage: widget.onManageProjects,
          ),
          if (state.projects.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
              child: Text(
                'Ninguno todavía. Creá uno para que varios agentes trabajen '
                'juntos sobre el mismo repo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final project in state.projects) ...[
            _ProjectRow(
              project: project,
              selected:
                  workspace.isProjectScoped &&
                  state.selectedProjectId == project.id,
              onTap: () => navigator.openProject(project.id),
            ),
            if (state.selectedProjectId == project.id) ...[
              _StateRow(
                project: project,
                selected: workspace.lens == WorkspaceLens.projectState,
                onTap: () => navigator.openProjectState(project.id),
              ),
              BoardsSection(
                projectId: project.id,
                workspace: workspace,
                expanded: _boardsOpen,
                onToggle: () => setState(() => _boardsOpen = !_boardsOpen),
              ),
              _SessionsSection(
                project: project,
                workspace: workspace,
                expanded: _sessionsOpen,
                onToggle: () => setState(() => _sessionsOpen = !_sessionsOpen),
              ),
            ],
          ],
          RequirementsGroup(
            selectedProjectId: state.selectedProjectId,
            selectedRequirementId: workspace.lens == WorkspaceLens.requirement
                ? RequirementsService.instance.notifier.data.selectedId
                : null,
            onSelect: navigator.openRequirement,
            onManage: () =>
                showFormPanel(context, child: const RequirementsScreen()),
            onAdd: () => openRequirementFormPanel(context),
          ),
          _LooseAgentsHead(
            onAdd: () => openUseAgentPanel(context),
            onManage: widget.onManageAgents,
          ),
          ReactiveViewModelBuilder<AgentsViewModel, AgentsState>(
            viewmodel: AgentsService.instance.notifier,
            build: (agentsState, viewmodel, keep) {
              // Sin las sesiones de Keel AI: el asistente vive en su ventana
              // flotante, no acá entre los agentes que registró el usuario.
              final agents = viewmodel.listableAgents;
              if (agents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  child: Text(
                    'Ninguno abierto. Usá un agente registrado para hablarle '
                    'directo, sin proyecto.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final agent in agents)
                    _LooseAgentRow(
                      agent: agent,
                      selected:
                          workspace.lens == WorkspaceLens.agent &&
                          agentsState.selectedAgentId == agent.id,
                      onTap: () => navigator.openAgent(agent.id),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// La sección Sesiones: la tercera hermana. Antes las sesiones colgaban del
/// proyecto sin encabezado, así que se leían como si fueran otra cosa que
/// Estado y Tableros cuando son exactamente lo mismo —una parte del
/// proyecto.
class _SessionsSection extends StatelessWidget {
  const _SessionsSection({
    required this.project,
    required this.workspace,
    required this.expanded,
    required this.onToggle,
  });

  final Project project;
  final WorkspaceState workspace;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final navigator = WorkspaceService.instance.notifier;
    final onSessions = workspace.lens == WorkspaceLens.session;
    final active = project.activeSessionId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SidebarSectionRow(
          label: 'Sesiones',
          selected: onSessions,
          expanded: expanded,
          onToggle: onToggle,
          // Sin ninguna abierta lleva igual al lente de sesiones, que es
          // donde está el botón para abrir una. Un click que no hace nada
          // porque no hay nada es peor que uno que te muestra por qué.
          onTap: () => active == null
              ? navigator.openNewSession(project.id)
              : navigator.openSession(project.id, active),
          trailing: SidebarCount(
            project.sessions.length,
            highlight: onSessions,
          ),
        ),
        if (expanded) ...[
          for (final session in project.sessions) ...[
            _SessionRow(
              session: session,
              projectId: project.id,
              // El `3/7` es de la SESIÓN: dos sesiones del mismo proyecto
              // pueden correr flujos de largos distintos, y contar las de
              // una sobre la escala de la otra sería mentir con precisión.
              totalSteps: ProjectsService.instance.notifier.nodeCountOf(
                session,
              ),
              selected: onSessions && active == session.id,
              onTap: () => navigator.openSession(project.id, session.id),
            ),
            // El plan solo se despliega en la sesión abierta: con cuatro
            // sesiones en el proyecto, cuatro planes a la vez convierten
            // el sidebar en una pared.
            if (active == session.id)
              SessionPlanList(
                projectId: project.id,
                sessionId: session.id,
                plan: session.plan,
              ),
          ],
          SidebarAddRow(
            label: 'Nueva sesión',
            onTap: () => navigator.openNewSession(project.id),
          ),
        ],
      ],
    );
  }
}

/// El encabezado de los agentes sueltos, con las mismas dos aberturas que el
/// de proyectos: `+` abre uno registrado como chat 1:1, y el otro lleva al
/// registro para crearlos o editarlos.
///
/// Los agentes se manejan desde acá y solo desde acá: la lista vivía también
/// en el rail de la izquierda, y eran dos columnas pegadas mostrando lo mismo.
class _LooseAgentsHead extends StatelessWidget {
  const _LooseAgentsHead({required this.onAdd, required this.onManage});

  final VoidCallback onAdd;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'AGENTES SUELTOS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Registrar o editar agentes',
            icon: const Icon(Icons.tune, size: 15),
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            padding: EdgeInsets.zero,
            onPressed: onManage,
          ),
          IconButton(
            tooltip: 'Usar un agente registrado',
            icon: const Icon(Icons.add, size: 15),
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            padding: EdgeInsets.zero,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// A 1:1 chat with a registered agent, outside any project.
class _LooseAgentRow extends StatelessWidget {
  const _LooseAgentRow({
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final Agent agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : null,
          border: Border(
            left: BorderSide(
              width: 2,
              color: selected ? agent.iconColor : Colors.transparent,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 5, 14, 5),
        child: Row(
          children: [
            AgentStatusIcon(
              color: agent.iconColor,
              selected: selected,
              isWorking: agent.isStreaming,
              contextRatio: agent.contextUsageRatio,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                agent.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead({
    required this.label,
    required this.onAdd,
    required this.onManage,
  });

  final String label;
  final VoidCallback onAdd;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Administrar proyectos',
            icon: const Icon(Icons.tune, size: 15),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            onPressed: onManage,
          ),
          IconButton(
            tooltip: 'Nuevo proyecto',
            icon: const Icon(Icons.add, size: 17),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatefulWidget {
  const _ProjectRow({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProjectRow> createState() => _ProjectRowState();
}

class _ProjectRowState extends State<_ProjectRow> {
  final _rename = InlineRenameHandle();

  Project get project => widget.project;
  bool get selected => widget.selected;

  @override
  void dispose() {
    _rename.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: widget.onTap,
      onDoubleTap: _rename.start,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : null,
          border: Border(
            left: BorderSide(
              width: 2,
              color: selected ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 5, 14, 5),
        child: Row(
          children: [
            Text(
              '#',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InlineRenameField(
                value: project.name,
                handle: _rename,
                hintText: 'Nombre del proyecto',
                validate: validateProjectName,
                onRename: (name) => ProjectsService.instance.notifier
                    .renameProject(project.id, name),
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // La marca de que este proyecto no es tuyo para decidir. Va acá,
            // en la lista, y no escondida en su ficha: es lo que cambia lo
            // que podés pedirle antes de abrirlo.
            if (!project.maintained) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'No lo mantengo: solo lectura',
                child: Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: scheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatefulWidget {
  const _SessionRow({
    required this.session,
    required this.projectId,
    required this.totalSteps,
    required this.selected,
    required this.onTap,
  });

  final Session session;
  final String projectId;
  final int totalSteps;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

/// La fila de una sesión. Doble click sobre el nombre lo edita ahí mismo: es
/// un rename, no un formulario, y mandarlo a un panel por un campo de texto
/// sería más ceremonia que la que el gesto merece.
class _SessionRowState extends State<_SessionRow> {
  final _rename = InlineRenameHandle();

  Session get session => widget.session;
  String get projectId => widget.projectId;
  int get totalSteps => widget.totalSteps;
  bool get selected => widget.selected;

  @override
  void dispose() {
    _rename.dispose();
    super.dispose();
  }

  Future<void> _confirmAndClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Text(
          'Se borra el hilo de "${session.title}" y el contexto que los agentes '
          'acumularon en ella. El proyecto queda igual, con sus agentes, '
          'reglas y documentos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      ProjectsService.instance.notifier.closeSession(projectId, session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final trailing = switch (session.status) {
      SessionStatus.finished => Icon(
        Icons.check,
        size: 13,
        color: scheme.tertiary,
      ),
      SessionStatus.failed => Icon(
        Icons.remove_circle_outline,
        size: 13,
        color: scheme.error,
      ),
      SessionStatus.running => Text(
        session.resolutionCase?.status.name ?? '···',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: scheme.primary,
        ),
      ),
    };

    return InkWell(
      onTap: widget.onTap,
      onDoubleTap: _rename.start,
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.fromLTRB(42, 3, 6, 3),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 6,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: InlineRenameField(
                value: session.title,
                handle: _rename,
                hintText: 'Nombre de la sesión',
                openEmptyWhen: kDefaultSessionTitle,
                onRename: (name) {
                  ProjectsService.instance.notifier.renameSession(
                    projectId,
                    session.id,
                    name,
                  );
                  return null;
                },
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? scheme.onSurface : scheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 4),
            trailing,
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.close, size: 13),
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              padding: EdgeInsets.zero,
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _confirmAndClose(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cómo va el proyecto. La primera de las tres secciones y la única sin
/// lista debajo: no hay estados, hay uno.
class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = ProjectsService.instance.notifier.radarBadgeFor(project);

    return SidebarSectionRow(
      label: 'Estado',
      selected: selected,
      onTap: onTap,
      trailing: badge.ok
          ? Text(
              '${badge.percent}%',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: selected ? scheme.primary : scheme.outline,
              ),
            )
          : Icon(Icons.warning_amber_rounded, size: 13, color: scheme.error),
    );
  }
}
