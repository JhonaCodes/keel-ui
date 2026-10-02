part of '../keel_e2e.dart';

/// Nombre del binario, sin extensión. `dart build cli` lo nombra igual en
/// toda plataforma de escritorio soportada (architecture §11.1, §15).
const kKeelE2eBinaryName = 'keel_e2e';

/// La variable de entorno que, si está puesta, gana sobre cualquier otra
/// búsqueda (architecture §14: "Supervisor host: binary resolution").
const kKeelE2eBinEnvVar = 'KEEL_E2E_BIN';

/// Resuelve el binario de keel_e2e, en este orden:
/// 1. [kKeelE2eBinEnvVar];
/// 2. el bundle de la app (`<App>.app/Contents/Resources/keel_e2e/bin/keel_e2e`);
/// 3. el build de desarrollo al lado del clon de keel-ui
///    (`<padre de keel-ui>/keel-e2e/build/bundle/bin/keel_e2e`), encontrado
///    subiendo desde `resolvedExecutablePath`.
///
/// `null` si ninguno existe. Pura: el único acceso a disco es [exists],
/// inyectado para poder probar los tres caminos sobre un árbol de carpetas
/// temporal, sin tocar el filesystem real.
String? resolveKeelE2eBinary({
  String? envOverride,
  required String resolvedExecutablePath,
  required bool Function(String path) exists,
}) {
  final env = envOverride?.trim();
  if (env != null && env.isNotEmpty) {
    return exists(env) ? env : null;
  }

  final bundlePath = _appBundleBinaryPath(resolvedExecutablePath);
  if (bundlePath != null && exists(bundlePath)) return bundlePath;

  final devPath = _siblingDevBuildBinaryPath(resolvedExecutablePath);
  if (devPath != null && exists(devPath)) return devPath;

  return null;
}

/// Sube desde [resolvedExecutablePath] buscando el `.app` que lo contiene, y
/// arma la ruta de recursos DENTRO de él. `null` si ningún ancestro termina
/// en `.app` — no estamos corriendo desde un bundle macOS.
String? _appBundleBinaryPath(String resolvedExecutablePath) {
  var dir = p.dirname(resolvedExecutablePath);
  while (true) {
    if (p.extension(dir) == '.app') {
      return p.join(
        dir,
        'Contents',
        'Resources',
        'keel_e2e',
        'bin',
        kKeelE2eBinaryName,
      );
    }
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

/// Sube desde [resolvedExecutablePath] buscando una carpeta llamada
/// `keel-ui` (el clon del repo), y arma la ruta del build hermano
/// `keel-e2e/build/bundle/bin/keel_e2e`. `null` si ningún ancestro se llama
/// así.
String? _siblingDevBuildBinaryPath(String resolvedExecutablePath) {
  var dir = p.dirname(resolvedExecutablePath);
  while (true) {
    if (p.basename(dir) == 'keel-ui') {
      final parent = p.dirname(dir);
      return p.join(
        parent,
        'keel-e2e',
        'build',
        'bundle',
        'bin',
        kKeelE2eBinaryName,
      );
    }
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}
