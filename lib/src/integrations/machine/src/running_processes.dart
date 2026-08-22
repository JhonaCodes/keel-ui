part of '../machine.dart';

/// Los procesos de CLI que Keel tiene vivos, y de parte de quién.
///
/// Existe porque `ps` sabe el pid y el comando pero no el motivo, y el
/// motivo es lo único que hace útil la lista: "claude al 78% de CPU" no
/// dice nada; "claude al 78%, por la sesión del bid que llega en cero", sí.
///
/// Un `Map` estático y no un ViewModel: no hay estado que mostrar en vivo,
/// solo una tabla que se consulta cuando la pantalla de Máquina está
/// abierta. Los turnos del task runner corren en otro isolate, así que su
/// pid llega por mensaje en vez de por referencia.
abstract final class RunningProcesses {
  static final Map<int, String> _byPid = {};

  static void register(int pid, String label) => _byPid[pid] = label;

  static void unregister(int pid) => _byPid.remove(pid);

  static Set<int> get pids => _byPid.keys.toSet();

  /// Quién lo largó, o vacío si el proceso no es de Keel.
  static String labelOf(int pid) => _byPid[pid] ?? '';
}
