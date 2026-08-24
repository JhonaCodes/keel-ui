import 'dart:convert';

/// Versión de una compilación de Keel.
///
/// El nombre usa semver (`major.minor.patch`) y el número después de `+` es
/// el build nativo. El major queda siempre bajo control manual.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  static final RegExp _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$');

  factory ReleaseVersion.parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw FormatException(
        'La versión debe tener el formato MAJOR.MINOR.PATCH+BUILD: $value',
      );
    }
    return ReleaseVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.parse(match.group(4)!),
    );
  }

  factory ReleaseVersion.fromPackage({
    required String version,
    required String buildNumber,
  }) {
    final build = int.tryParse(buildNumber) ?? 0;
    return ReleaseVersion.parse('$version+$build');
  }

  /// Siguiente compilación automática.
  ///
  /// `patch` usa veinte posiciones (`0..19`). Cuando tocaría `20`, vuelve a
  /// cero e incrementa `minor`. El `major` no se modifica nunca acá.
  ReleaseVersion next({int patchesPerMinor = 20}) {
    if (patchesPerMinor < 1) {
      throw ArgumentError.value(
        patchesPerMinor,
        'patchesPerMinor',
        'debe ser mayor que cero',
      );
    }
    final nextPatch = patch + 1;
    return ReleaseVersion(
      major: major,
      minor: nextPatch >= patchesPerMinor ? minor + 1 : minor,
      patch: nextPatch >= patchesPerMinor ? 0 : nextPatch,
      build: build + 1,
    );
  }

  String get buildName => '$major.$minor.$patch';

  String get pubspecValue => '$buildName+$build';

  @override
  int compareTo(ReleaseVersion other) {
    for (final comparison in [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
      build.compareTo(other.build),
    ]) {
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => pubspecValue;
}

/// Manifiesto pequeño que se publica junto al DMG.
class KeelReleaseManifest {
  const KeelReleaseManifest({
    required this.release,
    required this.downloadUrl,
    required this.sha256,
    required this.publishedAt,
  });

  final ReleaseVersion release;
  final Uri downloadUrl;
  final String sha256;
  final DateTime publishedAt;

  factory KeelReleaseManifest.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final build = json['build'];
    final downloadUrl = Uri.tryParse('${json['downloadUrl'] ?? ''}');
    final publishedAt = DateTime.tryParse('${json['publishedAt'] ?? ''}');
    final sha256 = '${json['sha256'] ?? ''}'.trim().toLowerCase();
    if (version is! String || build is! int) {
      throw const FormatException('El manifiesto no tiene versión y build.');
    }
    if (downloadUrl == null ||
        !downloadUrl.hasScheme ||
        downloadUrl.scheme != 'https') {
      throw const FormatException('La descarga del manifiesto no es válida.');
    }
    if (publishedAt == null) {
      throw const FormatException('La fecha del manifiesto no es válida.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('El SHA-256 del manifiesto no es válido.');
    }
    return KeelReleaseManifest(
      release: ReleaseVersion.fromPackage(
        version: version,
        buildNumber: '$build',
      ),
      downloadUrl: downloadUrl,
      sha256: sha256,
      publishedAt: publishedAt,
    );
  }

  factory KeelReleaseManifest.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('El manifiesto debe ser un objeto JSON.');
    }
    return KeelReleaseManifest.fromJson(decoded);
  }

  Map<String, Object?> toJson() => {
    'version': release.buildName,
    'build': release.build,
    'downloadUrl': downloadUrl.toString(),
    'sha256': sha256,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
  };
}

/// Cambia exclusivamente la línea `version:` del pubspec.
String withPubspecVersion(String pubspec, ReleaseVersion version) {
  final pattern = RegExp(
    r'^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
    multiLine: true,
  );
  final matches = pattern.allMatches(pubspec).length;
  if (matches != 1) {
    throw StateError(
      'Se esperaba exactamente una versión en pubspec.yaml y se encontraron '
      '$matches.',
    );
  }
  return pubspec.replaceFirst(pattern, 'version: ${version.pubspecValue}');
}
