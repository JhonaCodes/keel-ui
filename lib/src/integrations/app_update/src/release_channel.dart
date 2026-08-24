part of '../app_update.dart';

/// Archivo que se publica junto al DMG en el canal oficial.
const keelReleaseManifestUrl = 'https://jhonacode.com/keel/latest.json';

/// La versión instalada y la última publicada para descarga.
class InstalledReleaseStatus {
  const InstalledReleaseStatus({
    this.current,
    this.latest,
    this.checkedAt,
    this.error,
  });

  final ReleaseVersion? current;
  final KeelReleaseManifest? latest;
  final DateTime? checkedAt;

  /// Un fallo de red no invalida la versión instalada: solo impide saber si
  /// apareció otra. Se conserva para el tooltip y no se convierte en alerta.
  final String? error;

  bool get updateAvailable {
    final installed = current;
    final published = latest;
    return installed != null &&
        published != null &&
        published.release.compareTo(installed) > 0;
  }

  String get displayVersion => current?.buildName ?? '…';
}

/// Lee la versión del bundle y consulta el manifiesto público de releases.
Future<InstalledReleaseStatus> readInstalledRelease({
  http.Client? client,
  PackageInfo? packageInfo,
  Uri? manifestUri,
}) async {
  final checkedAt = DateTime.now();
  ReleaseVersion? current;
  try {
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    current = ReleaseVersion.fromPackage(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  } on Object catch (error) {
    return InstalledReleaseStatus(
      checkedAt: checkedAt,
      error: 'No pude leer la versión instalada: $error',
    );
  }

  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(manifestUri ?? Uri.parse(keelReleaseManifestUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    return InstalledReleaseStatus(
      current: current,
      latest: KeelReleaseManifest.decode(response.body),
      checkedAt: checkedAt,
    );
  } on Object catch (error) {
    return InstalledReleaseStatus(
      current: current,
      checkedAt: checkedAt,
      error: 'No pude revisar la última versión: $error',
    );
  } finally {
    if (ownedClient) httpClient.close();
  }
}
