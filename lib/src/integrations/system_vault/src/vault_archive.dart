part of '../system_vault.dart';

/// Nombre FIJO del respaldo dentro del vault. Fijo y no con fecha: el
/// historial lo lleva git, y un nombre con fecha dejaría un zip nuevo por
/// cada respaldo, para siempre.
const kVaultBackupFileName = 'keel-backup.zip';

/// Versión del formato del zip.
const kVaultFormatVersion = 1;

/// La fecha que llevan TODAS las entradas del zip.
///
/// Es una constante y no `DateTime.now()` porque de eso depende que el zip
/// sea determinista: mismo sistema, mismos bytes, y entonces `git commit`
/// contesta "nothing to commit" y el repo no engorda por haber apretado el
/// botón dos veces. Ver [encodeVault].
final _kFixedEntryDate = DateTime.utc(1980, 1, 1);

/// Un documento de saber más grande que esto no entra al zip.
///
/// El vault se sube a un repo: un binario enorme ahí queda en la historia
/// para siempre. Lo que se saltea se NOMBRA en el resultado del respaldo —
/// un tope silencioso se leería como "guardé todo" sin haberlo hecho.
const kMaxVaultDocBytes = 10 * 1024 * 1024;

/// Un zip que no es un respaldo de keel, o que lo es pero está roto.
class VaultFormatException implements Exception {
  final String message;
  const VaultFormatException(this.message);

  @override
  String toString() => message;
}

/// Lo que un vault contiene, ya en forma portable y sin nada de esta
/// máquina. Es lo que entra al zip y lo que sale de él.
class VaultContents {
  /// Categoría → entidades, tal cual [catalogAsJson].
  final Map<String, List<Map<String, dynamic>>> catalog;

  /// Los ajustes que sí viajan (ver [vaultSettingsOf]).
  final Map<String, dynamic> settings;

  /// `{name, description}` por secret. Nunca `value`.
  final List<Map<String, dynamic>> secrets;

  /// Base de saber → ruta relativa → bytes. Solo bases locales que viven
  /// FUERA del vault: las de adentro ya están en el repo, en claro.
  final Map<String, Map<String, Uint8List>> knowledgeDocs;

  const VaultContents({
    this.catalog = const {},
    this.settings = const {},
    this.secrets = const [],
    this.knowledgeDocs = const {},
  });

  int get catalogCount =>
      catalog.values.fold(0, (sum, entities) => sum + entities.length);

  int get documentCount =>
      knowledgeDocs.values.fold(0, (sum, files) => sum + files.length);
}

const _jsonWriter = JsonEncoder.withIndent('  ');

Uint8List _jsonBytes(Object? value) =>
    Uint8List.fromList(utf8.encode(_jsonWriter.convert(value)));

/// [contents] como los bytes de un zip.
///
/// El resultado es función PURA de [contents]: entradas en orden alfabético,
/// fecha fija en todas y ningún sello de tiempo adentro. Dos respaldos de un
/// sistema que no cambió dan bytes idénticos, que es lo que hace tolerable
/// guardar un binario en git — solo aparece un blob nuevo cuando algo cambió
/// de verdad.
Uint8List encodeVault(VaultContents contents) {
  final entries = <String, Uint8List>{
    'manifest.json': _jsonBytes({
      'keelVault': kVaultFormatVersion,
      'counts': {
        for (final category in kCatalogCategories)
          category: contents.catalog[category]?.length ?? 0,
        'secrets': contents.secrets.length,
        'documents': contents.documentCount,
      },
    }),
    'settings.json': _jsonBytes(contents.settings),
    'secrets.json': _jsonBytes(contents.secrets),
  };

  for (final entry in contents.catalog.entries) {
    for (final json in entry.value) {
      final name = json['name'] as String? ?? '';
      if (name.isEmpty) continue;
      entries['catalog/${entry.key}/${catalogFileNameFor(name)}'] = _jsonBytes(
        json,
      );
    }
  }

  for (final base in contents.knowledgeDocs.entries) {
    for (final doc in base.value.entries) {
      entries['knowledge/${base.key}/${doc.key}'] = doc.value;
    }
  }

  final archive = Archive();
  for (final name in entries.keys.toList()..sort()) {
    archive.add(ArchiveFile(name, entries[name]!.length, entries[name]!));
  }

  return Uint8List.fromList(
    ZipEncoder().encodeBytes(
      archive,
      level: DeflateLevel.bestCompression,
      modified: _kFixedEntryDate,
    ),
  );
}

/// Los [bytes] de un zip de vault, de vuelta en [VaultContents].
///
/// Lanza [VaultFormatException] si el archivo no es un respaldo de keel: un
/// zip cualquiera tiene que dar un mensaje que se entienda, no el error
/// crudo del decodificador.
VaultContents decodeVault(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (error) {
    throw VaultFormatException('No pude abrir el zip: $error');
  }

  final files = {
    for (final file in archive.files)
      if (file.isFile) file.name: file.readBytes() ?? Uint8List(0),
  };

  final manifest = files['manifest.json'];
  if (manifest == null) {
    throw const VaultFormatException(
      'Ese zip no es un respaldo de keel: no tiene manifest.json.',
    );
  }
  final version = _decodeJson(manifest, 'manifest.json');
  if (version is! Map || version['keelVault'] is! int) {
    throw const VaultFormatException(
      'El manifest no dice ser un respaldo de keel.',
    );
  }

  final catalog = <String, List<Map<String, dynamic>>>{};
  final knowledgeDocs = <String, Map<String, Uint8List>>{};

  for (final entry in files.entries) {
    final path = entry.key;
    if (path.startsWith('catalog/')) {
      final parts = path.split('/');
      if (parts.length < 3) continue;
      final json = _decodeJson(entry.value, path);
      if (json is! Map) continue;
      catalog
          .putIfAbsent(parts[1], () => <Map<String, dynamic>>[])
          .add(json.cast<String, dynamic>());
      continue;
    }
    if (path.startsWith('knowledge/')) {
      final parts = path.split('/');
      if (parts.length < 3) continue;
      final relative = parts.sublist(2).join('/');
      knowledgeDocs
          .putIfAbsent(parts[1], () => <String, Uint8List>{})[relative] =
          entry.value;
    }
  }

  final settings = _decodeJson(files['settings.json'], 'settings.json');
  final secrets = _decodeJson(files['secrets.json'], 'secrets.json');

  return VaultContents(
    catalog: catalog,
    settings: settings is Map ? settings.cast<String, dynamic>() : const {},
    secrets: [
      for (final secret in secrets is List ? secrets : const [])
        if (secret is Map) secret.cast<String, dynamic>(),
    ],
    knowledgeDocs: knowledgeDocs,
  );
}

Object? _decodeJson(Uint8List? bytes, String path) {
  if (bytes == null) return null;
  try {
    return jsonDecode(utf8.decode(bytes));
  } catch (error) {
    throw VaultFormatException('$path del respaldo está roto: $error');
  }
}
