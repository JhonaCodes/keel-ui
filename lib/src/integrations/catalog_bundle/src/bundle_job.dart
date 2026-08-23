part of '../catalog_bundle.dart';

/// Lo que hay que ir a buscar al disco para armar un paquete, y dónde
/// dejarlo.
///
/// Se arma en el isolate de la interfaz —es leer memoria— y se manda entero
/// a otro, por lo mismo que el respaldo: recorrer carpetas de saber, leer
/// cada archivo y comprimir con la mejor compresión es un freeze de varios
/// segundos si pasa donde se dibuja.
class BundleExportJob {
  const BundleExportJob({
    required this.destinationPath,
    required this.manifest,
    required this.catalog,
    this.knowledgeRoots = const {},
  });

  final String destinationPath;

  /// El manifiesto YA en JSON: cruzar la frontera con objetos planos es lo
  /// que hace que esto no dependa de qué se puede enviar y qué no.
  final Map<String, dynamic> manifest;

  final Map<String, List<Map<String, dynamic>>> catalog;

  /// Nombre de la base → carpeta absoluta, solo las locales que existen.
  final Map<String, String> knowledgeRoots;
}

/// Cómo salió.
class BundleWritten {
  const BundleWritten({
    required this.byteLength,
    required this.documentCount,
    required this.skipped,
  });

  final int byteLength;
  final int documentCount;

  /// Lo que quedó afuera por tamaño, con nombre y todo: un tope silencioso
  /// se lee como «guardé todo» sin haberlo hecho.
  final List<String> skipped;
}

/// Escribe el paquete. Corre en otro isolate.
BundleWritten writeBundleArchive(BundleExportJob job) {
  final skipped = <String>[];
  final docs = <String, Map<String, Uint8List>>{};

  for (final entry in job.knowledgeRoots.entries) {
    final files = readBundleDocuments(entry.key, entry.value, skipped);
    if (files.isNotEmpty) docs[entry.key] = files;
  }

  final contents = BundleContents(
    manifest: BundleManifest.fromJson(job.manifest),
    catalog: job.catalog,
    knowledgeDocs: docs,
  );
  final bytes = encodeBundle(contents);
  File(job.destinationPath).writeAsBytesSync(bytes);

  return BundleWritten(
    byteLength: bytes.length,
    documentCount: contents.documentCount,
    skipped: skipped,
  );
}

/// Los documentos de una base local: ruta relativa → bytes.
///
/// Los ocultos quedan afuera, igual que en el índice de saber y en el
/// respaldo: `.git` adentro de un paquete que se comparte es la carpeta de
/// otro viajando sin que nadie la haya pedido.
Map<String, Uint8List> readBundleDocuments(
  String baseName,
  String root,
  List<String> skipped,
) {
  final directory = Directory(root);
  if (root.trim().isEmpty || !directory.existsSync()) return const {};

  final prefix = root.endsWith('/') ? root : '$root/';
  final files = <String, Uint8List>{};
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.startsWith(prefix)) continue;
    final relative = entity.path.substring(prefix.length);
    if (relative.startsWith('.') || relative.contains('/.')) continue;
    if (entity.lengthSync() > kMaxBundleDocBytes) {
      skipped.add('$baseName/$relative');
      continue;
    }
    files[relative] = entity.readAsBytesSync();
  }
  return files;
}

/// Un paquete abierto y revisado, listo para que alguien decida.
class BundleReview {
  const BundleReview({required this.contents, required this.audit});

  final BundleContents contents;
  final BundleAudit audit;
}

/// Abre y revisa los bytes de un paquete. Corre en otro isolate: descomprimir
/// hasta 64 MB y pasarle veinte expresiones regulares a cada texto no es
/// trabajo de entre dos cuadros.
BundleReview inspectBundleBytes(Uint8List bytes) {
  final contents = decodeBundle(bytes);
  return BundleReview(contents: contents, audit: auditBundle(contents));
}
