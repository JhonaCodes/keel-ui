part of '../keel_e2e.dart';

/// `<Application Support>/keel-ui/e2e`, el `dataDir` que keel-ui le pasa al
/// engine (architecture §13: "`dataDir` es provisto por el host: dentro de
/// Keel, `<Application Support>/keel-ui/e2e`").
Future<String> keelE2eDataDir() async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'keel-ui', 'e2e');
}
