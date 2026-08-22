import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

/// Marcador que ocupa el lugar del directorio de scripts mientras la
/// configuración se arma.
///
/// La configuración de hooks se renderiza en el isolate principal —ahí están
/// los secrets y el catálogo— pero la carpeta donde van a vivir los scripts
/// recién existe cuando arranca el turno, y en el caso de una estación eso
/// pasa del otro lado de un `Isolate.spawn`. Así que se renderiza con este
/// marcador y [CliTurnWorkspace] lo reemplaza al escribir.
const kHookDirPlaceholder = '__KEEL_HOOK_DIR__';

/// Todo lo que un turno le deja en el disco al CLI, y su limpieza.
///
/// Un solo directorio 0700 (`createTemp` ya lo crea así) porque adentro van
/// valores de secrets resueltos: los de los MCP externos en `mcp.json`, y
/// los que declara un hook en su wrapper. Un argumento de línea de comandos
/// sería legible con `ps` para cualquier proceso del sistema; un archivo
/// 0700, no.
///
/// El perfil de codex es la excepción y no vive acá: codex solo lee perfiles
/// de `$CODEX_HOME`, así que se escribe ahí con un nombre único de este
/// turno y se borra igual en [dispose].
class CliTurnWorkspace {
  final Directory _directory;
  final File? _codexProfileFile;

  /// Ruta del `mcp.json`, o null si el turno no lleva MCP.
  final String? mcpConfigPath;

  /// Ruta del `settings.json` para `claude --settings`, o null si no hay
  /// hooks que aplicar.
  final String? claudeSettingsPath;

  /// Nombre del perfil para `codex -p`, o null si no hay hooks.
  final String? codexProfileName;

  const CliTurnWorkspace._(
    this._directory,
    this._codexProfileFile, {
    this.mcpConfigPath,
    this.claudeSettingsPath,
    this.codexProfileName,
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

    String? codexProfileName;
    File? codexProfileFile;
    if (codexHooksConfig != null) {
      // El nombre lleva el sufijo del temporal, que ya es único: dos
      // estaciones corriendo a la vez no pueden pisarse el perfil.
      codexProfileName = 'keel-${directory.path.split('_').last}';
      codexProfileFile = File('${_codexHome()}/$codexProfileName.config.toml');
      await codexProfileFile.parent.create(recursive: true);
      await codexProfileFile.writeAsString(
        codexHooksConfig.replaceAll(kHookDirPlaceholder, scriptDir),
      );
    }

    return CliTurnWorkspace._(
      directory,
      codexProfileFile,
      mcpConfigPath: mcpConfigPath,
      claudeSettingsPath: claudeSettingsPath,
      codexProfileName: codexProfileName,
    );
  }

  static String _codexHome() {
    final override = Platform.environment['CODEX_HOME'];
    if (override != null && override.isNotEmpty) return override;
    return '${Platform.environment['HOME'] ?? ''}/.codex';
  }

  /// Borra todo lo del turno. Se llama en un `finally`: si queda un wrapper
  /// con un secret adentro, quedó en el disco.
  Future<void> dispose() async {
    try {
      if (await _directory.exists()) {
        await _directory.delete(recursive: true);
      }
      if (_codexProfileFile != null && await _codexProfileFile.exists()) {
        await _codexProfileFile.delete();
      }
    } catch (error) {
      Log.w('No pude limpiar el temporal del turno: $error');
    }
  }
}
