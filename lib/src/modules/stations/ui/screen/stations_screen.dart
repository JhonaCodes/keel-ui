import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/ui/screen/station_form_screen.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/station_tile.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones'),
        actions: [
          IconButton(
            tooltip: 'Registrar nueva',
            icon: const Icon(Icons.add),
            onPressed: () => openStationFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<StationsViewModel, StationsState>(
        viewmodel: StationsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.stations.isEmpty) {
            return const Center(
              child: Text('Todavía no registraste ninguna estación.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.stations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                StationTile(station: state.stations[index]),
          );
        },
      ),
    );
  }
}
