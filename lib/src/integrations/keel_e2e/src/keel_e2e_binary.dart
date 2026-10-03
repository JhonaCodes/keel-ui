part of '../keel_e2e.dart';

/// The keel_e2e engine embedded in this app. Every macOS build, debug or
/// release, copies it into `<App>.app/Contents/Resources/keel_e2e/` through
/// the Xcode build phase "Embed keel-e2e" (`scripts/embed_keel_e2e.sh`), with
/// its ONNX Runtime library and its OCR models. There is no other place to
/// look: no environment variable, no checkout next to Keel.
abstract final class KeelE2eBinary {
  const KeelE2eBinary._();

  /// The executable's name, the same on every desktop platform
  /// `dart build cli` supports (architecture §11.1, §15).
  static const fileName = 'keel_e2e';

  /// The engine inside the running app, or `null` if this build lacks it.
  static String? embedded() => resolve(
    resolvedExecutablePath: Platform.resolvedExecutable,
    exists: (path) => File(path).existsSync(),
  );

  /// Walks up from [resolvedExecutablePath] to the `.app` that contains it
  /// and returns the embedded engine when [exists] confirms it. `null` when
  /// the executable does not run from a macOS bundle or the bundle lacks
  /// the engine. Pure: [exists] is the only disk access, so a test can lay
  /// out a temporary bundle.
  static String? resolve({
    required String resolvedExecutablePath,
    required bool Function(String path) exists,
  }) {
    final bundled = _bundledPath(resolvedExecutablePath);
    return bundled != null && exists(bundled) ? bundled : null;
  }

  static String? _bundledPath(String resolvedExecutablePath) {
    var dir = p.dirname(resolvedExecutablePath);
    while (true) {
      if (p.extension(dir) == '.app') {
        return p.join(dir, 'Contents', 'Resources', fileName, 'bin', fileName);
      }
      final parent = p.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
  }
}
