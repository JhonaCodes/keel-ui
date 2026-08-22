part of '../catalog_backup.dart';

/// Versión del formato del archivo de respaldo.
const kBackupFormatVersion = 1;

/// Una sección elegible del respaldo. Mapea 1:1 a las categorías del
/// catálogo portable de `catalog_sync`. Los secrets NO son una sección:
/// son un opt-in aparte, para que "todo" nunca los arrastre sin querer.
enum BackupSection {
  skills('skills', 'Skills'),
  rules('rules', 'Reglas'),
  tools('tools', 'Tools'),
  workflows('workflows', 'Workflows'),
  mcpServers('mcp_servers', 'Integraciones MCP'),
  knowledgeBases('knowledge_bases', 'Bases de saber (con sus documentos)'),
  agents('profiles', 'Agentes'),
  stations('stations', 'Estaciones');

  const BackupSection(this.category, this.label);

  /// La clave de categoría en la forma portable del catálogo.
  final String category;
  final String label;

  static BackupSection? byCategory(String category) => BackupSection.values
      .where((section) => section.category == category)
      .firstOrNull;
}

/// Lo que un archivo de respaldo trae, mirado ANTES de aplicar: qué hay en
/// cada sección y qué nombres pisarían algo que ya existe. El import nunca
/// aplica a ciegas — primero se muestra esto.
class BackupPreview {
  /// Nombres por sección, tal como vienen en el archivo.
  final Map<BackupSection, List<String>> names;

  /// El subconjunto de [names] que ya existe localmente (el merge por
  /// nombre lo actualizaría en lugar de crearlo).
  final Map<BackupSection, List<String>> conflicts;

  /// Base de saber → cuántos documentos trae el archivo.
  final Map<String, int> knowledgeDocCounts;

  final int secretCount;
  final int secretsWithValue;

  const BackupPreview({
    this.names = const {},
    this.conflicts = const {},
    this.knowledgeDocCounts = const {},
    this.secretCount = 0,
    this.secretsWithValue = 0,
  });

  List<BackupSection> get sectionsPresent => [
    for (final section in BackupSection.values)
      if ((names[section] ?? const []).isNotEmpty) section,
  ];

  bool get isEmpty =>
      sectionsPresent.isEmpty && knowledgeDocCounts.isEmpty && secretCount == 0;
}
