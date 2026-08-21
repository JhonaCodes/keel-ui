import 'package:keel_ui/src/modules/agents/model/code_language.dart';

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _markdownExtensions = {'md', 'markdown'};
const _mermaidExtensions = {'mmd', 'mermaid'};

/// Extensiones que se abren como texto plano aunque no tengan resaltado
/// propio — un `.txt` o un `.env` se lee, no se manda a "abrir con el
/// sistema".
const _plainTextExtensions = {'txt', 'log', 'csv', 'env', 'gitignore'};

/// Cómo se muestra un documento de una base. La decisión sale de la
/// extensión y nada más: es el único dato confiable sin abrir el archivo.
enum KnowledgeDocumentKind {
  /// Markdown con el renderer del chat — sus bloques ```mermaid``` y
  /// ```svg``` se dibujan como diagramas.
  markdown,

  /// Diagrama mermaid suelto, en su propio archivo.
  mermaid,

  svg,
  image,

  /// Texto o código, con resaltado por extensión.
  code,

  /// Ni se muestra ni se intenta: se ofrece abrirlo con la app del sistema.
  unsupported,
}

KnowledgeDocumentKind _kindFor(String path) {
  final fileName = path.split('/').last.toLowerCase();
  final dot = fileName.lastIndexOf('.');
  if (dot == -1) return KnowledgeDocumentKind.code;
  final extension = fileName.substring(dot + 1);

  if (_markdownExtensions.contains(extension)) {
    return KnowledgeDocumentKind.markdown;
  }
  if (_mermaidExtensions.contains(extension)) {
    return KnowledgeDocumentKind.mermaid;
  }
  if (extension == 'svg') return KnowledgeDocumentKind.svg;
  if (_imageExtensions.contains(extension)) return KnowledgeDocumentKind.image;
  if (_plainTextExtensions.contains(extension)) {
    return KnowledgeDocumentKind.code;
  }
  return codeLanguageForPath(path) == 'plaintext'
      ? KnowledgeDocumentKind.unsupported
      : KnowledgeDocumentKind.code;
}

/// Un documento abierto en la pantalla de Saber. El [text] viene cargado
/// solo para las clases que se leen como texto; una imagen se pinta desde
/// [absolutePath] y no pasa por memoria dos veces.
class KnowledgeDocument {
  final String baseId;
  final String relativePath;
  final String absolutePath;
  final KnowledgeDocumentKind kind;
  final String text;

  /// Por qué no se pudo leer, cuando no se pudo. Vacío si está bien.
  final String problem;

  const KnowledgeDocument({
    required this.baseId,
    required this.relativePath,
    required this.absolutePath,
    required this.kind,
    this.text = '',
    this.problem = '',
  });

  /// Clasifica [relativePath] sin leer el archivo — el contenido lo carga
  /// el ViewModel solo si la clase lo necesita.
  static KnowledgeDocumentKind kindOf(String relativePath) =>
      _kindFor(relativePath);

  bool get isText =>
      kind == KnowledgeDocumentKind.markdown ||
      kind == KnowledgeDocumentKind.mermaid ||
      kind == KnowledgeDocumentKind.svg ||
      kind == KnowledgeDocumentKind.code;

  String get language => codeLanguageForPath(relativePath);

  String get fileName => relativePath.split('/').last;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeDocument &&
          runtimeType == other.runtimeType &&
          baseId == other.baseId &&
          relativePath == other.relativePath &&
          absolutePath == other.absolutePath &&
          kind == other.kind &&
          text == other.text &&
          problem == other.problem;

  @override
  int get hashCode =>
      Object.hash(baseId, relativePath, absolutePath, kind, text, problem);

  @override
  String toString() =>
      'KnowledgeDocument($relativePath, kind: ${kind.name}, '
      'chars: ${text.length})';
}
