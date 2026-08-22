import 'package:keel_ui/src/integrations/machine/machine.dart';

class MachineSnapshot {
  /// Los CLIs encontrados. Vacío hasta la primera búsqueda.
  final List<CliService> services;

  final MachineState machine;

  /// Si se está buscando ahora. Solo aplica a los servicios: el estado del
  /// fierro se relee cada pocos segundos y parpadear en cada vuelta sería
  /// ruido.
  final bool probing;

  const MachineSnapshot({
    this.services = const [],
    this.machine = const MachineState(),
    this.probing = false,
  });

  int get supportedCount => services
      .where((service) => service.supported && service.installed)
      .length;

  MachineSnapshot copyWith({
    List<CliService>? services,
    MachineState? machine,
    bool? probing,
  }) => MachineSnapshot(
    services: services ?? this.services,
    machine: machine ?? this.machine,
    probing: probing ?? this.probing,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineSnapshot &&
          probing == other.probing &&
          identical(services, other.services) &&
          identical(machine, other.machine);

  @override
  int get hashCode => Object.hash(services.length, machine.load, probing);

  @override
  String toString() =>
      'MachineSnapshot(services: ${services.length}, probing: $probing)';
}
