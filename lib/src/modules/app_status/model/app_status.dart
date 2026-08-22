import 'package:flutter/foundation.dart';

/// Qué está haciendo la app que le impide contestar.
///
/// Es un CONTADOR y no un booleano porque dos tareas largas pueden
/// solaparse —restaurar un respaldo mientras se indexa una base de saber— y
/// la que termine primero no puede apagar el aviso de la otra.
class AppStatusState {
  const AppStatusState({this.running = const {}});

  /// Etiqueta → cuántas veces está corriendo.
  final Map<String, int> running;

  bool get busy => running.isNotEmpty;

  /// Lo primero que se puso a correr, que es lo que se muestra. Con dos
  /// tareas a la vez, nombrar las dos es más ruido que información.
  String? get label => running.keys.firstOrNull;

  AppStatusState copyWith({Map<String, int>? running}) =>
      AppStatusState(running: running ?? this.running);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppStatusState &&
          runtimeType == other.runtimeType &&
          mapEquals(running, other.running);

  @override
  int get hashCode => Object.hashAll([
    for (final entry in running.entries) Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'AppStatusState(${running.keys.join(', ')})';
}
