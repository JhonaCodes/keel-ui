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
  Future<T> during<T>(String label, Future<T> Function() work) =>
      _track(label, work, blocking: true);

  /// Corre [work] avisando, sin atenuar ni tragarse los clicks.
  ///
  /// Para lo que no te pisa: un respaldo automático, un índice que se
  /// refresca. Bloquear la app por algo que no compite con lo que estás
  /// haciendo es una interrupción sin razón, y encima enseña a ignorar el
  /// aviso cuando SÍ importa.
  Future<T> inBackground<T>(String label, Future<T> Function() work) =>
      _track(label, work, blocking: false);

  Future<T> _track<T>(
    String label,
    Future<T> Function() work, {
    required bool blocking,
  }) async {
    _bump(label, blocking: blocking, by: 1);
    try {
      return await work();
    } finally {
      _bump(label, blocking: blocking, by: -1);
    }
  }

  void _bump(String label, {required bool blocking, required int by}) {
    final counts = Map<String, int>.from(
      blocking ? data.running : data.background,
    );
    final left = (counts[label] ?? 0) + by;
    if (left <= 0) {
      counts.remove(label);
    } else {
      counts[label] = left;
    }
    updateState(
      blocking
          ? data.copyWith(running: counts)
          : data.copyWith(background: counts),
    );
  }
}

mixin AppStatusService {
  static final ReactiveNotifier<AppStatusViewModel> instance =
      ReactiveNotifier<AppStatusViewModel>(() => AppStatusViewModel());
}
