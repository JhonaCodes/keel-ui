import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

/// El PATH real del usuario, leído de su shell de login.
///
/// Una app de escritorio abierta desde el Finder —o desde un lanzador de
/// Linux— no hereda el PATH de la terminal: la arranca `launchd`, que le pasa
/// el mínimo del sistema. Todo lo que Keel lanza (`claude`, `codex`, `npx`,
/// los runtimes de las tools) se instala fuera de ese mínimo, así que la app
/// instalada no encontraba nada que `flutter run` sí encontraba: el turno
/// moría con `/bin/sh: claude: command not found` y el panel de servicios
/// mostraba la máquina como si no tuviera ningún CLI.
///
/// Se lee UNA vez por engine: abrir un shell de login cuesta decenas de
/// milisegundos y el PATH no cambia mientras la app está viva.
class UserShellPath {
  UserShellPath._();

  /// Marcas alrededor del valor. Un `.zshrc` interactivo imprime lo que se le
  /// antoje —banners, avisos de `nvm`, el prompt instantáneo de powerlevel10k—
  /// y sin delimitadores toda esa basura entraría al PATH.
  static const _begin = '__KEEL_PATH_BEGIN__';
  static const _end = '__KEEL_PATH_END__';

  /// Un rc que se cuelga deja a Keel sin los CLIs del usuario; no puede
  /// además dejarlo sin arrancar.
  static const _timeout = Duration(seconds: 5);

  static Future<String>? _reading;

  /// El PATH con el que hay que lanzar cualquier CLI del usuario.
  ///
  /// La memoización es la que hace que esto sea barato: los ocho probes de
  /// [detectServices] arrancan a la vez y sin ella abrirían ocho shells.
  static Future<String> resolved() => _reading ??= _read();

  /// Para pasarle a `Process.start` / `Process.run`.
  ///
  /// Con `includeParentEnvironment` en true (el default) esto se monta ENCIMA
  /// del entorno heredado: pisa PATH y deja todo lo demás como estaba.
  static Future<Map<String, String>> environment() async => {
    'PATH': await resolved(),
  };

  /// La ruta absoluta de [binary], o null si no está en el PATH del usuario.
  ///
  /// Hace falta ADEMÁS del PATH porque `Process.start` sin `runInShell`
  /// resuelve el nombre con `execvp`, que mira el PATH del proceso que llama
  /// —el de la app— y no el `environment` que se le está pasando. Ahí, pasar
  /// el PATH bueno no alcanza: hay que pasar la ruta ya resuelta.
  static Future<String?> locate(String binary) async {
    if (binary.contains(Platform.pathSeparator)) return binary;
    for (final directory in (await resolved()).split(_separator)) {
      if (directory.isEmpty) continue;
      final candidate = File('$directory${Platform.pathSeparator}$binary');
      if (await candidate.exists()) return candidate.path;
    }
    return null;
  }

  static String get _separator => Platform.isWindows ? ';' : ':';

  /// Lo que la app recibió al arrancar. Es la respuesta correcta en Windows y
  /// la única disponible cuando leer el shell falla.
  static String get _inherited => Platform.environment['PATH'] ?? '';

  static Future<String> _read() async {
    // Windows no tiene shell de login: ahí el PATH heredado ya es el bueno.
    if (Platform.isWindows) return _inherited;

    final shell = Platform.environment['SHELL'];
    if (shell == null || shell.isEmpty) {
      Log.w('Sin \$SHELL: los CLIs se buscan con el PATH heredado');
      return _inherited;
    }

    try {
      // `-l` trae `.zprofile`/`.bash_profile`, que es donde deja el PATH el
      // `brew shellenv`; `-i` trae `.zshrc`/`.bashrc`, que es donde lo dejan
      // nvm, pyenv, mise y compañía. Hacen falta los dos: cada gestor eligió
      // un archivo distinto y el usuario no tiene por qué saber cuál.
      final result = await Process.run(shell, [
        '-ilc',
        'printf "%s%s%s" "$_begin" "\$PATH" "$_end"',
      ]).timeout(_timeout);

      final output = '${result.stdout}';
      final start = output.indexOf(_begin);
      final end = output.indexOf(_end);
      if (start < 0 || end < start) {
        Log.w('$shell no devolvió un PATH legible; se usa el heredado');
        return _inherited;
      }

      final path = output.substring(start + _begin.length, end).trim();
      if (path.isEmpty) {
        Log.w('$shell devolvió un PATH vacío; se usa el heredado');
        return _inherited;
      }

      Log.i(
        'PATH del usuario leído de $shell: '
        '${path.split(_separator).length} entradas',
      );
      return path;
    } on Object catch (error) {
      Log.e('No se pudo leer el PATH de $shell', error: error);
      return _inherited;
    }
  }
}
