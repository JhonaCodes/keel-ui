/// Los contextos de Máquina, en el orden en que se muestran. Cuentas va
/// primero: es a donde lleva el riel.
enum MachineTab {
  accounts('Cuentas'),
  usage('Consumo'),
  installed('Instalado'),
  hardware('Equipo');

  const MachineTab(this.label);

  final String label;
}
