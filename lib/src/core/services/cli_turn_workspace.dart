import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

/// Marcador que ocupa el lugar del directorio de scripts mientras la
/// configuración se arma.
///
/// La configuración de hooks se renderiza en el isolate principal —ahí están
/// los secrets y el catálogo— pero la carpeta donde van a vivir los scripts
/// recién existe cuando arranca el turno, y en el caso de un proyecto eso
/// pasa del otro lado de un `Isolate.spawn`. Así que se renderiza con este
/// marcador y [CliTurnWorkspace] lo reemplaza al escribir.
const kHookDirPlaceholder = '__KEEL_HOOK_DIR__';

/// La marca que el wrapper de un hook deja en stderr cuando bloquea.
///
/// Vive acá y no junto al render porque la leen los dos extremos: el wrapper
/// que la escribe, y el parser del CLI que la reconoce para poder decir cuál
/// hook frenó. Un bloqueo de hook llega por el mismo canal que un error
/// común de herramienta, y esta marca es lo único que los distingue.
const kHookDenialMarker = 'keel:hook';

/// Todo lo que un turno le deja en el disco al CLI, y su limpieza.
///
/// Un solo directorio 0700 (`createTemp` ya lo crea así) porque adentro van
/// valores de secrets resueltos: los de los MCP externos en `mcp.json`, y
/// los que declara un hook en su wrapper. Un argumento de línea de comandos
/// sería legible con `ps` para cualquier proceso del sistema; un archivo
/// 0700, no.
///
/// Codex no lee nada de acá salvo los wrappers de hooks: su configuración
/// viaja por `-c clave=valor` (ver `codex_config_overrides.dart`), porque
/// `exec resume` no carga perfiles. Los overrides de hooks se devuelven ya
/// con la ruta real de los scripts puesta.
class CliTurnWorkspace {
  final Directory _directory;

  /// Ruta del `mcp.json`, o null si el turno no lleva MCP.
  final String? mcpConfigPath;

  /// Ruta del `settings.json` para `claude --settings`, o null si no hay
  /// hooks que aplicar.
  final String? claudeSettingsPath;

  /// Los overrides `-c` de hooks para codex, uno por evento, con el
  /// directorio de scripts ya resuelto. Vacío si no hay hooks.
  final List<String> codexConfigOverrides;

  const CliTurnWorkspace._(
    this._directory, {
    this.mcpConfigPath,
    this.claudeSettingsPath,
    this.codexConfigOverrides = const [],
  });

  /// Escribe lo que haga falta y devuelve las rutas. Todo es opcional: un
  /// turno sin MCP ni hooks crea igual el directorio y no escribe nada, que
  /// es más simple que decidir si crearlo.
  static Future<CliTurnWorkspace> create({
    String? mcpConfig,
    String? claudeSettings,
    String? codexHooksConfig,
    Map<String, String> hookFiles = const {},
  }) async {
    final directory = await Directory.systemTemp.createTemp('keel_turn_');
    final scriptDir = '${directory.path}/hooks';

    String? mcpConfigPath;
    if (mcpConfig != null) {
      final file = File('${directory.path}/mcp.json');
      await file.writeAsString(mcpConfig);
      mcpConfigPath = file.path;
    }

    if (hookFiles.isNotEmpty) {
      await Directory(scriptDir).create(recursive: true);
      for (final entry in hookFiles.entries) {
        await File('$scriptDir/${entry.key}').writeAsString(entry.value);
      }
    }

    String? claudeSettingsPath;
    if (claudeSettings != null) {
      final file = File('${directory.path}/settings.json');
      await file.writeAsString(
        claudeSettings.replaceAll(kHookDirPlaceholder, scriptDir),
      );
      claudeSettingsPath = file.path;
    }

    // Un override por línea (ver `renderCodexOverrides`): la ruta de los
    // scripts recién existe acá, así que acá se reemplaza el marcador.
    final codexConfigOverrides = codexHooksConfig == null
        ? const <String>[]
        : [
            for (final line in codexHooksConfig.split('\n'))
              if (line.trim().isNotEmpty)
                line.replaceAll(kHookDirPlaceholder, scriptDir),
          ];

    return CliTurnWorkspace._(
      directory,
      mcpConfigPath: mcpConfigPath,
      claudeSettingsPath: claudeSettingsPath,
      codexConfigOverrides: codexConfigOverrides,
    );
  }

  /// Borra todo lo del turno. Se llama en un `finally`: si queda un wrapper
  /// con un secret adentro, quedó en el disco.
  Future<void> dispose() async {
    try {
      if (await _directory.exists()) {
        await _directory.delete(recursive: true);
      }
    } catch (error) {
      Log.w('No pude limpiar el temporal del turno: $error');
    }
  }
}
