import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';

Future<void> openTaskAgentPicker(
  BuildContext context, {
  required String stationId,
  required String taskId,
}) {
  return showFormPanel<void>(
    context,
    child: TaskAgentPicker(stationId: stationId, taskId: taskId),
  );
}

/// Adds/removes agents for ONE task. The station's standing roster is
/// read-only here — changing it for every task is the station form's job.
class TaskAgentPicker extends StatelessWidget {
  const TaskAgentPicker({
    super.key,
    required this.stationId,
    required this.taskId,
  });

  final String stationId;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agentes de esta tarea')),
      body: ReactiveViewModelBuilder<StationsViewModel, StationsState>(
        viewmodel: StationsService.instance.notifier,
        build: (state, stationsViewModel, keep) {
          final station = state.stations
              .where((entry) => entry.id == stationId)
              .firstOrNull;
          final task = station?.tasks
              .where((entry) => entry.id == taskId)
              .firstOrNull;
          if (station == null || task == null) {
            return const Center(child: Text('La tarea ya no existe.'));
          }
          return _PickerBody(station: station, task: task);
        },
      ),
    );
  }
}

class _PickerBody extends StatelessWidget {
  const _PickerBody({required this.station, required this.task});

  final Station station;
  final StationTask task;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (profilesState, profilesViewModel, keep) {
        final stations = StationsService.instance.notifier;
        final standing = profilesState.profiles
            .where((profile) => station.profileIds.contains(profile.id))
            .toList();
        final extras = profilesState.profiles
            .where((profile) => task.extraProfileIds.contains(profile.id))
            .toList();
        final available = profilesState.profiles
            .where(
              (profile) =>
                  profile.name != kKeelAiHandle &&
                  !station.profileIds.contains(profile.id) &&
                  !task.extraProfileIds.contains(profile.id),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SectionLabel(
              'Miembros de la estación (en todas las tareas)',
            ),
            for (final profile in standing)
              ListTile(
                dense: true,
                leading: const Icon(Icons.badge_outlined, size: 18),
                title: Text(profile.name),
                subtitle: profile.role.isEmpty ? null : Text(profile.role),
              ),
            const Divider(height: 16),
            const _SectionLabel('Solo en ESTA tarea'),
            if (extras.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Ninguno todavía.'),
              ),
            for (final profile in extras)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_add_alt_outlined, size: 18),
                title: Text(profile.name),
                subtitle: profile.role.isEmpty ? null : Text(profile.role),
                trailing: IconButton(
                  tooltip: 'Quitar de esta tarea',
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () => stations.removeAgentFromTask(
                    station.id,
                    task.id,
                    profile.id,
                  ),
                ),
              ),
            const Divider(height: 16),
            const _SectionLabel('Agregar a esta tarea'),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('No quedan agentes registrados por sumar.'),
              ),
            for (final profile in available)
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 18),
                title: Text(profile.name),
                subtitle: profile.role.isEmpty ? null : Text(profile.role),
                onTap: () => stations.addAgentToTask(
                  station.id,
                  task.id,
                  profile.id,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
