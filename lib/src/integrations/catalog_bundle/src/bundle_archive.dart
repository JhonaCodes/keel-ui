part of '../catalog_bundle.dart';

/// La fecha de TODAS las entradas del zip.
///
/// Fija, como en el vault: un paquete de la misma cosa da los mismos bytes,
/// así que se le puede sacar un hash y comparar dos descargas. Un catálogo
/// que algún día publique paquetes lo va a necesitar; y mientras tanto hace
/// que exportar dos veces no dé dos archivos distintos sin motivo.
final _kBundleEntryDate = DateTime.utc(1980, 1, 1);

/// Un documento de saber más grande que esto no entra al paquete.
const kMaxBundleDocBytes = 10 * 1024 * 1024;

/// Un paquete entero más grande que esto no se importa.
///
/// El tope existe del lado de la IMPORTACIÓN sobre todo: un zip que se
/// descomprime a gigabytes es la forma más barata de tumbar la app de otro,
/// y el que descarga de un enlace no eligió qué le mandan.
const kMaxBundleBytes = 64 * 1024 * 1024;

const _bundleJson = JsonEncoder.withIndent('  ');

Uint8List _bundleJsonBytes(Object? value) =>
    Uint8List.fromList(utf8.encode(_bundleJson.convert(value)));

/// [contents] como los bytes de un zip.
Uint8List encodeBundle(BundleContents contents) {
  final entries = <String, Uint8List>{
    'manifest.json': _bundleJsonBytes(contents.manifest.toJson()),
    'README.md': Uint8List.fromList(utf8.encode(bundleReadme(contents))),
  };

  for (final entry in contents.catalog.entries) {
    for (final json in entry.value) {
      final name = json['name'] as String? ?? '';
      if (name.isEmpty) continue;
      entries['catalog/${entry.key}/${catalogFileNameFor(name)}'] =
          _bundleJsonBytes(json);
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
      modified: _kBundleEntryDate,
    ),
  );
}

/// Los [bytes] de un paquete, de vuelta en [BundleContents].
///
/// Lanza [BundleFormatException] con un mensaje que se entienda: quien abre
/// esto puede haber descargado cualquier cosa de cualquier lado.
BundleContents decodeBundle(Uint8List bytes) {
  if (bytes.length > kMaxBundleBytes) {
    throw BundleFormatException(
      'Ese paquete pesa ${_megabytes(bytes.length)} MB y el tope son '
      '${kMaxBundleBytes ~/ (1024 * 1024)}. No lo abro.',
    );
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (error) {
    throw BundleFormatException('No pude abrir el zip: $error');
  }

  final files = <String, Uint8List>{};
  var uncompressed = 0;
  for (final file in archive.files) {
    if (!file.isFile) continue;
    // Una entrada que se sale de su carpeta al descomprimirse es un
    // `zip slip`, y no hay ningún paquete legítimo que la necesite.
    if (_escapesTheArchive(file.name)) {
      throw BundleFormatException(
        'El paquete trae una ruta que se sale de su carpeta '
        '("${file.name}"). No lo abro.',
      );
    }
    uncompressed += file.size;
    if (uncompressed > kMaxBundleBytes) {
      throw const BundleFormatException(
        'El paquete se descomprime a algo enorme. No lo abro.',
      );
    }
    files[file.name] = file.readBytes() ?? Uint8List(0);
  }

  final manifestBytes = files['manifest.json'];
  if (manifestBytes == null) {
    throw const BundleFormatException(
      'Ese zip no es un paquete de keel: no tiene manifest.json.',
    );
  }
  final manifestJson = _decodeBundleJson(manifestBytes, 'manifest.json');
  if (manifestJson is! Map) {
    throw const BundleFormatException('El manifiesto no es un objeto JSON.');
  }
  final manifest = BundleManifest.fromJson(
    manifestJson.cast<String, dynamic>(),
  );
  if (manifest.formatVersion > kBundleFormatVersion) {
    throw BundleFormatException(
      'Ese paquete es de un formato más nuevo (v${manifest.formatVersion}) '
      'que el que esta versión de keel entiende (v$kBundleFormatVersion). '
      'Actualizá keel.',
    );
  }

  final catalog = <String, List<Map<String, dynamic>>>{};
  final knowledgeDocs = <String, Map<String, Uint8List>>{};

  for (final entry in files.entries) {
    final parts = entry.key.split('/');
    if (parts.length < 3) continue;
    if (parts.first == 'catalog') {
      final json = _decodeBundleJson(entry.value, entry.key);
      if (json is! Map) continue;
      catalog
          .putIfAbsent(parts[1], () => <Map<String, dynamic>>[])
          .add(json.cast<String, dynamic>());
      continue;
    }
    if (parts.first == 'knowledge') {
      knowledgeDocs.putIfAbsent(
        parts[1],
        () => <String, Uint8List>{},
      )[parts.sublist(2).join('/')] = entry.value;
    }
  }

  return BundleContents(
    manifest: manifest,
    catalog: withLegacyCategoryNames(catalog),
    knowledgeDocs: knowledgeDocs,
  );
}

/// Si [path] intenta escribir fuera de la carpeta del paquete.
bool _escapesTheArchive(String path) {
  if (path.startsWith('/') || path.startsWith('\\')) return true;
  if (RegExp(r'^[a-zA-Z]:').hasMatch(path)) return true;
  return path.split(RegExp(r'[/\\]')).contains('..');
}

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

Object? _decodeBundleJson(Uint8List bytes, String path) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } catch (error) {
    throw BundleFormatException('$path del paquete está roto: $error');
  }
}

/// El nombre de archivo sugerido para un paquete.
String bundleFileNameOf(BundleKind kind, String name) {
  // El punto no sobrevive: un nombre con `..` adentro llega hasta acá tal
  // cual y el sugerido de un diálogo de guardar es lo que la mayoría
  // acepta sin leer.
  final clean = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'keel-${kind.alias}-${clean.isEmpty ? 'paquete' : clean}.zip';
}

/// El README que va adentro del zip.
///
/// Para el que lo descarga y lo abre con el Finder antes de meterlo en keel:
/// un zip de JSONs sin una hoja que diga qué es y qué se lleva puesto es
/// justo el tipo de cosa que uno instala sin mirar.
String bundleReadme(BundleContents contents) {
  final manifest = contents.manifest;
  final lines = <String>[
    '# ${manifest.name}',
    '',
    'Un paquete de **keel**: un ${manifest.kind.label} con todo lo que '
        'necesita para funcionar.',
    if (manifest.summary.isNotEmpty) ...['', '> ${manifest.summary}'],
    '',
    '## Qué trae',
    '',
    '| Categoría | Cuántos |',
    '|---|---|',
    for (final entry in manifest.counts.entries)
      '| ${entry.key} | ${entry.value} |',
    if (contents.documentCount > 0)
      '| documentos de saber | ${contents.documentCount} |',
  ];

  if (manifest.requiredSecrets.isNotEmpty) {
    lines.addAll([
      '',
      '## Qué necesita de tu lado',
      '',
      'Estos secrets tienen que existir en tu keel, con estos nombres. El '
          'paquete lleva los nombres y **nunca** los valores:',
      '',
      for (final secret in manifest.requiredSecrets) '- `$secret`',
    ]);
  }

  lines.addAll([
    '',
    '## Cómo se instala',
    '',
    'En keel: **Agentes → Importar paquete**, y elegí este archivo. Antes de '
        'instalar nada vas a ver qué trae y una revisión de seguridad de lo '
        'que hay adentro.',
    '',
    '---',
    '',
    'Exportado el ${manifest.exportedAt.toIso8601String()} · '
        'formato v${manifest.formatVersion}',
    '',
  ]);

  return lines.join('\n');
}
