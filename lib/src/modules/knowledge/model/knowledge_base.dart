import 'package:flutter/foundation.dart';

final RegExp _knowledgeBaseNameFormat = RegExp(r'^[A-Za-z0-9_-]{1,32}$');

/// Cuánto del `INDEX.md` de una base entra en el turno de un agente. Es la
/// portada, no el contenido: pasado este tope se corta, porque una portada
/// larga deja de ser un mapa y pasa a ser territorio.
const kKnowledgeIndexPromptLimit = 4000;

/// Archivos que, si están en la raíz de una base, se inyectan ENTEROS en el
/// turno de quien tenga esa base. Dicen qué hay y cuándo mirar cada cosa.
///
/// En orden de preferencia: un `INDEX.md` es una portada escrita a
/// propósito para esto; el `README.md` que casi toda carpeta de
/// documentación ya tiene sirve igual y evita tener que sumarle un archivo
/// nuevo a un repo ajeno solo para poder consultarlo.
const kKnowledgeIndexFileNames = ['INDEX.md', 'README.md'];

/// Devuelve un mensaje de error si [value] no sirve como nombre de base, o
/// null si es válido. El nombre viaja por referencia desde estaciones y
/// perfiles, y además es el nombre de la carpeta del espejo git, así que no
/// admite espacios ni separadores de ruta.
String? validateKnowledgeBaseName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 32) return 'Máximo 32 caracteres.';
  if (value.contains(' ')) return 'No se permiten espacios.';
  if (!_knowledgeBaseNameFormat.hasMatch(value)) {
    return 'Solo letras, números, "-" y "_".';
  }
  return null;
}

/// De dónde salen los documentos de una base.
enum KnowledgeSource {
  /// Repo git clonado a un espejo dentro de Application Support. Se
  /// sincroniza con pull.
  git(alias: 'git', label: 'Repo git'),

  /// Una carpeta que ya está en el disco del usuario. NO se copia: la base
  /// apunta ahí. No hay nada que sincronizar.
  local(alias: 'local', label: 'Carpeta local');

  final String alias;
  final String label;

  const KnowledgeSource({required this.alias, required this.label});

  static KnowledgeSource? tryFromAlias(String alias) {
    for (final source in values) {
      if (source.alias == alias) return source;
    }
    return null;
  }
}

/// Un cuerpo de documentación con frontera de contexto: `NUI`, `CONNECT`,
/// `KIWIO`. Una estación (o un perfil oráculo) declara qué bases ve, y en el
/// turno de sus agentes entra el MAPA de esas bases —ruta, tamaño, carpetas
/// de primer nivel y su `INDEX.md`—, nunca los documentos enteros: el agente
/// los abre con sus propias herramientas cuando le hacen falta.
class KnowledgeBase {
  final String id;
  final String name;

  /// Una línea: qué contesta esta base. Es lo primero que lee un agente
  /// para decidir si vale la pena buscar acá.
  final String description;

  final KnowledgeSource source;

  /// Solo para [KnowledgeSource.git].
  final String gitUrl;
  final String gitBranch;

  /// Solo para [KnowledgeSource.local]. Vacío en una base recién importada:
  /// las rutas nunca viajan en un export, y la UI la pide al abrirla.
  final String localPath;

  final DateTime createdAt;

  const KnowledgeBase({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    required this.createdAt,
    this.gitUrl = '',
    this.gitBranch = '',
    this.localPath = '',
  });

  /// Una base local sin carpeta todavía — importada, o con la ruta borrada.
  /// No indexa ni entra en el turno de nadie hasta que se le da una.
  bool get needsFolder =>
      source == KnowledgeSource.local && localPath.trim().isEmpty;

  KnowledgeBase copyWith({
    String? name,
    String? description,
    KnowledgeSource? source,
    String? gitUrl,
    String? gitBranch,
    String? localPath,
  }) {
    return KnowledgeBase(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      source: source ?? this.source,
      gitUrl: gitUrl ?? this.gitUrl,
      gitBranch: gitBranch ?? this.gitBranch,
      localPath: localPath ?? this.localPath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'source': source.alias,
    'gitUrl': gitUrl,
    'gitBranch': gitBranch,
    'localPath': localPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory KnowledgeBase.fromJson(Map<String, dynamic> json) {
    return KnowledgeBase(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      source:
          KnowledgeSource.tryFromAlias(json['source'] as String? ?? '') ??
          KnowledgeSource.git,
      gitUrl: json['gitUrl'] as String? ?? '',
      gitBranch: json['gitBranch'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeBase &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          source == other.source &&
          gitUrl == other.gitUrl &&
          gitBranch == other.gitBranch &&
          localPath == other.localPath &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    source,
    gitUrl,
    gitBranch,
    localPath,
    createdAt,
  );

  @override
  String toString() =>
      'KnowledgeBase(id: $id, name: $name, source: ${source.alias})';
}

/// Un nodo del árbol de una base: carpeta con hijos, o documento hoja.
/// [relativePath] siempre cuelga de la raíz de su base, con "/" como
/// separador, así el mismo string sirve para mostrar y para abrir.
class KnowledgeNode {
  final String name;
  final String relativePath;
  final bool isDirectory;
  final List<KnowledgeNode> children;

  const KnowledgeNode({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    this.children = const [],
  });

  /// Documentos colgando de este nodo, a cualquier profundidad.
  int get documentCount => isDirectory
      ? children.fold(0, (total, child) => total + child.documentCount)
      : 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeNode &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          relativePath == other.relativePath &&
          isDirectory == other.isDirectory &&
          listEquals(children, other.children);

  @override
  int get hashCode =>
      Object.hash(name, relativePath, isDirectory, Object.hashAll(children));

  @override
  String toString() =>
      'KnowledgeNode($relativePath, dir: $isDirectory, docs: $documentCount)';
}

/// El estado en disco de una base: su raíz resuelta, su árbol y su portada.
/// Se arma escaneando la carpeta, nunca se persiste — la fuente de verdad
/// es el disco, y persistir un índice solo abre la puerta a que mienta.
class KnowledgeIndex {
  final String rootPath;
  final List<KnowledgeNode> nodes;

  /// Contenido de `INDEX.md` si la base tiene uno en su raíz, recortado a
  /// [kKnowledgeIndexPromptLimit].
  final String indexContent;

  /// Por qué la base no se pudo indexar (carpeta inexistente, sin clonar
  /// todavía). Vacío cuando está bien.
  final String problem;

  const KnowledgeIndex({
    required this.rootPath,
    this.nodes = const [],
    this.indexContent = '',
    this.problem = '',
  });

  bool get isEmpty => nodes.isEmpty;

  int get documentCount =>
      nodes.fold(0, (total, node) => total + node.documentCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeIndex &&
          runtimeType == other.runtimeType &&
          rootPath == other.rootPath &&
          indexContent == other.indexContent &&
          problem == other.problem &&
          listEquals(nodes, other.nodes);

  @override
  int get hashCode =>
      Object.hash(rootPath, Object.hashAll(nodes), indexContent, problem);

  @override
  String toString() =>
      'KnowledgeIndex($rootPath, docs: $documentCount, problem: $problem)';
}
