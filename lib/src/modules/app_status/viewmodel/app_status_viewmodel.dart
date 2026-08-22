import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/app_status/model/app_status.dart';

/// Lo que la app está haciendo y que justifica que no conteste todavía.
///
/// Un solo lugar donde se dice "esperá", en vez de que cada pantalla invente
/// el suyo. Lo consume [AppBusyOverlay], que vive arriba de todo.
class AppStatusViewModel extends ViewModel<AppStatusState> {
  AppStatusViewModel() : super(const AppStatusState());

  @override
  void init() {}

  /// Corre [work] con la app marcada como ocupada.
  ///
  /// Es el único punto de entrada a propósito: el `finally` garantiza que
  /// una tarea que explota no deje la app oscurecida para siempre, que es el
  /// modo de falla de todo indicador global hecho a mano.
  Future<T> during<T>(String label, Future<T> Function() work) async {
    _begin(label);
    try {
      return await work();
    } finally {
      _end(label);
    }
  }

  void _begin(String label) {
    final running = Map<String, int>.from(data.running);
    running.update(label, (count) => count + 1, ifAbsent: () => 1);
    updateState(data.copyWith(running: running));
  }

  void _end(String label) {
    final running = Map<String, int>.from(data.running);
    final left = (running[label] ?? 1) - 1;
    if (left <= 0) {
      running.remove(label);
    } else {
      running[label] = left;
    }
    updateState(data.copyWith(running: running));
  }
}

mixin AppStatusService {
  static final ReactiveNotifier<AppStatusViewModel> instance =
      ReactiveNotifier<AppStatusViewModel>(() => AppStatusViewModel());
}
