import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/machine/machine.dart';
import 'package:keel_ui/src/modules/machine/model/machine_snapshot.dart';

class MachineViewModel extends ViewModel<MachineSnapshot> {
  MachineViewModel() : super(const MachineSnapshot());

  /// Cada cuánto se relee el fierro mientras la pantalla está abierta. Tres
  /// segundos es lo que hace falta para que un número se vea moverse; menos
  /// es un timer trabajando para que nadie lo note.
  static const _tick = Duration(seconds: 3);

  /// Cuánto vale una búsqueda de servicios. Un CLI no se instala mientras
  /// mirás la pantalla, y `which` + `--version` sobre ocho binarios no es
  /// gratis.
  static const _servicesTtl = Duration(minutes: 10);

  Timer? _timer;
  DateTime? _servicesReadAt;

  @override
  void init() {
    updateSilently(const MachineSnapshot());
  }

  /// Empieza a mirar. Lo llama la pantalla al montarse.
  ///
  /// Si el timer corriera siempre, la app estaría gastando procesos para
  /// dibujar un número que nadie está mirando — que es exactamente lo que
  /// hacía que tardara veinte segundos en dejarse tocar.
  void startWatching() {
    unawaited(refreshServices());
    unawaited(_readMachine());
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => unawaited(_readMachine()));
  }

  void stopWatching() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }

  /// Busca los CLIs. Con [force] ignora el cacheo — es el botón de la
  /// pantalla, para después de instalar algo.
  Future<void> refreshServices({bool force = false}) async {
    final last = _servicesReadAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _servicesTtl) {
      return;
    }

    updateState(data.copyWith(probing: true));
    try {
      final services = await detectServices();
      _servicesReadAt = DateTime.now();
      updateState(data.copyWith(services: services, probing: false));
    } catch (error) {
      Log.e('No pude revisar qué CLIs hay instalados', error: error);
      updateState(data.copyWith(probing: false));
    }
  }

  Future<void> _readMachine() async {
    try {
      final machine = await readMachineState(pids: RunningProcesses.pids);
      updateState(data.copyWith(machine: machine));
    } catch (error) {
      // El fierro es información de contexto: si `sysctl` falla, la pantalla
      // sigue sirviendo para lo demás.
      Log.w('No pude leer el estado de la máquina: $error');
    }
  }
}

mixin MachineService {
  static final ReactiveNotifier<MachineViewModel> instance =
      ReactiveNotifier<MachineViewModel>(() => MachineViewModel());
}
