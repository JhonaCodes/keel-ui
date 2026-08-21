import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/ui/screen/station_form_screen.dart';

class StationTile extends StatelessWidget {
  const StationTile({super.key, required this.station});

  final Station station;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar estación'),
        content: Text(
          'Se eliminará "#${station.name}" y todas sus tareas. Esta acción '
          'no se puede deshacer.',
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
      StationsService.instance.notifier.deleteStation(station.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        '#${station.name}',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
      ),
      isThreeLine: true,
      onTap: () => StationsService.instance.notifier.selectStation(station.id),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (station.purpose.isNotEmpty) Text(station.purpose),
          Text(
            '${station.profileIds.length} agente(s) · '
            '${station.workflowIds.length} workflow(s) · '
            '${station.tasks.length} tarea(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openStationFormScreen(context, initial: station),
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
