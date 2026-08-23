import 'package:flutter/foundation.dart';

/// Qué está haciendo la app que le impide contestar.
///
/// Es un CONTADOR y no un booleano porque dos tareas largas pueden
/// solaparse —restaurar un respaldo mientras se indexa una base de saber— y
/// la que termine primero no puede apagar el aviso de la otra.
class AppStatusState {
  const AppStatusState({this.running = const {}, this.background = const {}});

  /// Etiqueta → cuántas veces está corriendo. Estas SÍ atenúan la app.
  final Map<String, int> running;

  /// Lo que corre sin pisarte: se avisa, no se bloquea.
  ///
  /// La diferencia no es de duración sino de RIESGO. Restaurar un respaldo
  /// reemplaza el sistema abajo tuyo, y seguir tocando mientras pasa es cómo
  /// se pierde trabajo. Escribir un zip con una foto de lo que ya está en
  /// memoria no le hace nada a nadie: atenuar la app cada quince minutos por
  /// eso era una interrupción sin ninguna razón detrás.
  final Map<String, int> background;

  bool get busy => running.isNotEmpty;
  bool get working => background.isNotEmpty;

  /// Lo primero que se puso a correr, que es lo que se muestra. Con dos
  /// tareas a la vez, nombrar las dos es más ruido que información.
  String? get label => running.keys.firstOrNull ?? background.keys.firstOrNull;

  AppStatusState copyWith({
    Map<String, int>? running,
    Map<String, int>? background,
  }) => AppStatusState(
    running: running ?? this.running,
    background: background ?? this.background,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppStatusState &&
          runtimeType == other.runtimeType &&
          mapEquals(running, other.running) &&
          mapEquals(background, other.background);

  @override
  int get hashCode => Object.hashAll([
    for (final entry in running.entries) Object.hash(entry.key, entry.value),
    for (final entry in background.entries) Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() =>
      'AppStatusState(bloquea: ${running.keys.join(', ')}, '
      'de fondo: ${background.keys.join(', ')})';
}
