import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/use_agent_panel.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/task_plan_list.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// The channel list: stations, and under the selected one, its tasks. The
/// station is the durable thing; tasks are opened, run and closed inside it.
class StationsSidebar extends StatelessWidget {
  const StationsSidebar({
    super.key,
    required this.state,
    required this.stationFocused,
    required this.onSelectStation,
    required this.onSelectAgent,
    required this.onNewStation,
    required this.onManageStations,
    required this.onManageAgents,
  });

  final StationsState state;
  final bool stationFocused;
  final ValueChanged<String> onSelectStation;
  final ValueChanged<String> onSelectAgent;
  final VoidCallback onNewStation;
  final VoidCallback onManageStations;
  final VoidCallback onManageAgents;

  @override
  Widget build(BuildContext context) {
    // Subscribed, not read off the singleton: the workflow catalogue loads
    // asynchronously, and the task counters need to appear when it lands.
    return ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
      viewmodel: WorkflowsService.instance.notifier,
      build: (workflowsState, viewmodel, keep) => _SidebarList(
        state: state,
        stationFocused: stationFocused,
        onSelectStation: onSelectStation,
        onSelectAgent: onSelectAgent,
        onNewStation: onNewStation,
        onManageStations: onManageStations,
        onManageAgents: onManageAgents,
      ),
    );
  }
}

class _SidebarList extends StatelessWidget {
  const _SidebarList({
    required this.state,
    required this.stationFocused,
    required this.onSelectStation,
    required this.onSelectAgent,
    required this.onNewStation,
    required this.onManageStations,
    required this.onManageAgents,
  });

  final StationsState state;
  final bool stationFocused;
  final ValueChanged<String> onSelectStation;
  final ValueChanged<String> onSelectAgent;
  final VoidCallback onNewStation;
  final VoidCallback onManageStations;
  final VoidCallback onManageAgents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 210,
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14),
        children: [
          _GroupHead(
            label: 'Estaciones',
            onAdd: onNewStation,
            onManage: onManageStations,
          ),
          if (state.stations.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
              child: Text(
                'Ninguna todavía. Creá una para que varios agentes trabajen '
                'juntos con un workflow.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final station in state.stations) ...[
            _StationRow(
              station: station,
              selected: stationFocused && state.selectedStationId == station.id,
              onTap: () => onSelectStation(station.id),
            ),
            if (state.selectedStationId == station.id) ...[
              for (final task in station.tasks) ...[
                _TaskRow(
                  task: task,
                  stationId: station.id,
                  totalSteps: StationsService.instance.notifier.stepCountFor(
                    station,
                  ),
                  selected: station.activeTaskId == task.id,
                ),
                // El plan solo se despliega en la tarea abierta: con cuatro
                // tareas en la estación, cuatro planes a la vez convierten
                // el sidebar en una pared.
                if (station.activeTaskId == task.id)
                  TaskPlanList(
                    stationId: station.id,
                    taskId: task.id,
                    plan: task.plan,
                    taskIsRunning: task.isRunning,
                  ),
              ],
              _NewTaskButton(
                onPressed: () =>
                    StationsService.instance.notifier.createTask(station.id),
              ),
            ],
          ],
          _LooseAgentsHead(
            onAdd: () => openUseAgentPanel(context),
            onManage: onManageAgents,
          ),
          ReactiveViewModelBuilder<AgentsViewModel, AgentsState>(
            viewmodel: AgentsService.instance.notifier,
            build: (state, viewmodel, keep) {
              // Sin las sesiones de Keel AI: el asistente vive en su ventana
              // flotante, no acá entre los agentes que registró el usuario.
              final agents = viewmodel.listableAgents;
              if (agents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  child: Text(
                    'Ninguno abierto. Usá un agente registrado para hablarle '
                    'directo, sin estación.',
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
                          !stationFocused && state.selectedAgentId == agent.id,
                      onTap: () => onSelectAgent(agent.id),
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

/// El encabezado de los agentes sueltos, con las mismas dos aberturas que el
/// de estaciones: `+` abre uno registrado como chat 1:1, y el otro lleva al
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

/// A 1:1 chat with a registered agent, outside any station.
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
            tooltip: 'Administrar estaciones',
            icon: const Icon(Icons.tune, size: 15),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            onPressed: onManage,
          ),
          IconButton(
            tooltip: 'Nueva estación',
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

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.selected,
    required this.onTap,
  });

  final Station station;
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
              child: Text(
                station.name,
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

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    required this.task,
    required this.stationId,
    required this.totalSteps,
    required this.selected,
  });

  final StationTask task;
  final String stationId;
  final int totalSteps;
  final bool selected;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

/// La fila de una tarea. Doble click sobre el nombre lo edita ahí mismo: es
/// un rename, no un formulario, y mandarlo a un panel por un campo de texto
/// sería más ceremonia que la que el gesto merece.
class _TaskRowState extends State<_TaskRow> {
  bool _editing = false;
  late final _controller = TextEditingController(text: widget.task.title);
  final _focusNode = FocusNode();

  StationTask get task => widget.task;
  String get stationId => widget.stationId;
  int get totalSteps => widget.totalSteps;
  bool get selected => widget.selected;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = task.title == kDefaultTaskTitle ? '' : task.title;
    setState(() => _editing = true);
    _focusNode.requestFocus();
  }

  void _commit() {
    if (!_editing) return;
    setState(() => _editing = false);
    StationsService.instance.notifier.renameTask(
      stationId,
      task.id,
      _controller.text,
    );
  }

  Future<void> _confirmAndClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar tarea'),
        content: Text(
          'Se borra el hilo de "${task.title}" y el contexto que los agentes '
          'acumularon en ella. La estación queda igual, con sus agentes, '
          'reglas y documentos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar tarea'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      StationsService.instance.notifier.closeTask(stationId, task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final trailing = switch (task.status) {
      StationTaskStatus.finished => Icon(
        Icons.check,
        size: 13,
        color: scheme.tertiary,
      ),
      StationTaskStatus.failed => Icon(
        Icons.remove_circle_outline,
        size: 13,
        color: scheme.error,
      ),
      StationTaskStatus.running => Text(
        totalSteps == 0
            ? '···'
            : '${(task.currentStepIndex + 1).clamp(1, totalSteps)}/$totalSteps',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: scheme.primary,
        ),
      ),
    };

    return InkWell(
      onTap: () =>
          StationsService.instance.notifier.selectTask(stationId, task.id),
      onDoubleTap: _startEditing,
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.fromLTRB(30, 4, 6, 4),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 6,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _editing
                  ? Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) _commit();
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onSubmitted: (_) => _commit(),
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Nombre de la tarea',
                          hintStyle: TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                  : Tooltip(
                      message: 'Doble click para renombrar',
                      waitDuration: const Duration(milliseconds: 900),
                      child: Text(
                        task.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? scheme.onSurface : scheme.outline,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            trailing,
            IconButton(
              tooltip: 'Cerrar tarea',
              icon: const Icon(Icons.close, size: 13),
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              padding: EdgeInsets.zero,
              onPressed: () => _confirmAndClose(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens another task in the same station. Deliberately a real button: the
/// composer alone can only ever continue the task that is already open, so
/// without this there is no way to start a second one.
class _NewTaskButton extends StatelessWidget {
  const _NewTaskButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 6, 14, 10),
        child: Row(
          children: [
            Icon(Icons.add, size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              'Nueva tarea',
              style: TextStyle(
                fontSize: 12,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
