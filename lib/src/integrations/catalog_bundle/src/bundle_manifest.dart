part of '../catalog_bundle.dart';

/// Versión del formato del paquete. Sube cuando cambie de forma que un keel
/// viejo ya no pueda leerlo.
const kBundleFormatVersion = 1;

/// Qué se puede empaquetar.
///
/// Los tres son «una cosa que alguien querría instalar entera». Un proyecto
/// NO está acá: su directorio de trabajo es de esta máquina y sin él no es
/// nada — lo que de un proyecto sirve compartir es su workflow.
enum BundleKind {
  agent('agent', 'agente'),
  workflow('workflow', 'workflow'),
  skill('skill', 'skill');

  const BundleKind(this.alias, this.label);

  final String alias;
  final String label;

  static BundleKind? fromAlias(String alias) =>
      BundleKind.values.where((kind) => kind.alias == alias).firstOrNull;

  /// La categoría del catálogo donde vive la raíz de un paquete de este tipo.
  String get rootCategory => switch (this) {
    BundleKind.agent => 'profiles',
    BundleKind.workflow => 'workflows',
    BundleKind.skill => 'skills',
  };
}

/// La tapa del paquete: lo que se puede saber de él sin desarmarlo.
///
/// Existe con vistas a un catálogo público: una lista de paquetes se arma
/// leyendo solo esto, sin abrir el zip entero ni confiar en su contenido.
class BundleManifest {
  const BundleManifest({
    required this.kind,
    required this.name,
    required this.exportedAt,
    this.formatVersion = kBundleFormatVersion,
    this.summary = '',
    this.requiredSecrets = const [],
    this.counts = const {},
  });

  final int formatVersion;
  final BundleKind kind;

  /// El nombre de la raíz: el handle del agente, el nombre del workflow o de
  /// la skill.
  final String name;

  /// Una línea de qué es. Sale del rol del agente, del «cuándo aplicarlo»
  /// del workflow o de la primera línea de la skill.
  final String summary;

  final DateTime exportedAt;

  /// Qué secrets hace falta tener creados de este lado para que el paquete
  /// sirva. Solo NOMBRES: un valor no viaja nunca.
  final List<String> requiredSecrets;

  /// Categoría → cuántas entidades trae. Es lo que muestra una ficha de
  /// catálogo sin descargar nada.
  final Map<String, int> counts;

  int get entityCount => counts.values.fold(0, (sum, count) => sum + count);

  Map<String, dynamic> toJson() => {
    'keelBundle': formatVersion,
    'kind': kind.alias,
    'name': name,
    'summary': summary,
    'exportedAt': exportedAt.toIso8601String(),
    'requiredSecrets': requiredSecrets,
    'counts': counts,
  };

  static BundleManifest fromJson(Map<String, dynamic> json) {
    final kind = BundleKind.fromAlias(json['kind'] as String? ?? '');
    if (json['keelBundle'] is! int || kind == null) {
      throw const BundleFormatException(
        'Ese zip no es un paquete de keel: el manifiesto no lo dice.',
      );
    }
    return BundleManifest(
      formatVersion: json['keelBundle'] as int,
      kind: kind,
      name: json['name'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      requiredSecrets: [
        for (final secret in json['requiredSecrets'] as List? ?? const [])
          if (secret is String) secret,
      ],
      counts: {
        for (final entry in (json['counts'] as Map? ?? const {}).entries)
          if (entry.value is int) '${entry.key}': entry.value as int,
      },
    );
  }
}

/// Un paquete abierto: su tapa, su catálogo en la forma portable de siempre
/// y los documentos de las bases de saber que se lleva.
class BundleContents {
  const BundleContents({
    required this.manifest,
    this.catalog = const {},
    this.knowledgeDocs = const {},
  });

  final BundleManifest manifest;

  /// Categoría → entidades, exactamente la forma de [catalogAsJson]. Es lo
  /// que hace que instalar un paquete sea el mismo merge que restaurar un
  /// respaldo, sin un segundo camino de entrada que mantener.
  final Map<String, List<Map<String, dynamic>>> catalog;

  /// Base de saber → ruta relativa → bytes.
  final Map<String, Map<String, Uint8List>> knowledgeDocs;

  int get documentCount =>
      knowledgeDocs.values.fold(0, (sum, files) => sum + files.length);

  /// Las entidades de [category], vacías si no vino ninguna.
  List<Map<String, dynamic>> of(String category) =>
      catalog[category] ?? const [];
}

/// Un zip que no es un paquete de keel, o que lo es pero está roto.
class BundleFormatException implements Exception {
  final String message;
  const BundleFormatException(this.message);

  @override
  String toString() => message;
}
