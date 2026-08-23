import 'dart:io';

/// Crea un binario falso llamado [name] con el contenido de [script] en un
/// directorio temporal, listo para pasarse como `userPath` — así
/// `Process.start(name, ...)` lo encuentra sin tocar el PATH real de la
/// máquina que corre el test. El caller es responsable de borrar el
/// directorio devuelto (`addTearDown`).
Directory createFakeCliBin(String name, String script) {
  final dir = Directory.systemTemp.createTempSync('keel-fake-cli-');
  final file = File('${dir.path}/$name');
  file.writeAsStringSync(script);
  final chmod = Process.runSync('chmod', ['+x', file.path]);
  if (chmod.exitCode != 0) {
    throw StateError('No pude marcar $name como ejecutable: ${chmod.stderr}');
  }
  return dir;
}

/// El `userPath` que le corresponde a un binario falso creado con
/// [createFakeCliBin]: el fake primero (para que `claude`/`codex` lo
/// resuelvan a él) y el PATH real del sistema después — el script fake
/// sigue necesitando comandos reales como `sh`/`sleep`.
String fakeCliUserPath(Directory bin) {
  final systemPath = Platform.environment['PATH'] ?? '/usr/bin:/bin';
  return '${bin.path}:$systemPath';
}
