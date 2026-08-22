part of '../catalog_shape.dart';

/// Una sección elegible de un respaldo. Mapea 1:1 a las categorías de
/// [kCatalogCategories]. Los secrets NO son una sección: se tratan aparte en
/// cada destino, para que "todo" nunca los arrastre sin querer.
enum BackupSection {
  skills('skills', 'Skills'),
  rules('rules', 'Reglas'),
  hooks('hooks', 'Hooks'),
  tools('tools', 'Tools'),
  workflows('workflows', 'Workflows'),
  mcpServers('mcp_servers', 'Integraciones MCP'),
  knowledgeBases('knowledge_bases', 'Bases de saber'),
  agents('profiles', 'Agentes'),
  projects('projects', 'Proyectos'),
  requirements('requirements', 'Requerimientos');

  const BackupSection(this.category, this.label);

  /// La clave de categoría en la forma portable del catálogo.
  final String category;
  final String label;

  static BackupSection? byCategory(String category) => BackupSection.values
      .where((section) => section.category == category)
      .firstOrNull;
}

/// Lo que un respaldo trae, mirado ANTES de aplicar: qué hay en cada sección
/// y qué nombres pisarían algo que ya existe. Ningún import aplica a ciegas
/// — primero se muestra esto.
class BackupPreview {
  /// Nombres por sección, tal como vienen en el respaldo.
  final Map<BackupSection, List<String>> names;

  /// El subconjunto de [names] que ya existe localmente (el merge por
  /// nombre lo actualizaría en lugar de crearlo).
  final Map<BackupSection, List<String>> conflicts;

  /// Base de saber → cuántos documentos trae el respaldo.
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

/// Arma el preview de un [catalog] en forma portable contra el catálogo
/// vivo. Vive acá y no en cada destino porque "qué pisa esto" se contesta
/// igual venga de un zip o de un archivo suelto.
BackupPreview backupPreviewOf(
  Map<String, dynamic> rawCatalog, {
  Map<String, int> knowledgeDocCounts = const {},
  int secretCount = 0,
  int secretsWithValue = 0,
}) {
  final catalog = withLegacyCategoryNames(rawCatalog);
  final names = <BackupSection, List<String>>{};
  final conflicts = <BackupSection, List<String>>{};

  for (final entry in catalog.entries) {
    final section = BackupSection.byCategory(entry.key);
    if (section == null) continue;
    final inFile = [
      for (final json in (entry.value as List? ?? const []))
        if (json is Map && json['name'] is String) json['name'] as String,
    ];
    if (inFile.isEmpty) continue;
    names[section] = inFile;
    final existing = existingCatalogNames(section);
    conflicts[section] = inFile
        .where((name) => existing.contains(name))
        .toList();
  }

  return BackupPreview(
    names: names,
    conflicts: conflicts,
    knowledgeDocCounts: knowledgeDocCounts,
    secretCount: secretCount,
    secretsWithValue: secretsWithValue,
  );
}

/// Los nombres que [section] ya tiene en esta máquina.
Set<String> existingCatalogNames(BackupSection section) {
  return switch (section) {
    BackupSection.skills => {
      for (final skill in SkillsService.instance.notifier.data.skills)
        skill.name,
    },
    BackupSection.rules => {
      for (final rule in RulesService.instance.notifier.data.rules) rule.name,
    },
    BackupSection.hooks => {
      for (final hook in HooksService.instance.notifier.data.hooks) hook.name,
    },
    BackupSection.tools => {
      for (final tool in ToolsService.instance.notifier.data.tools) tool.name,
    },
    BackupSection.workflows => {
      for (final workflow in WorkflowsService.instance.notifier.data.workflows)
        workflow.name,
    },
    BackupSection.mcpServers => {
      for (final server in McpServersService.instance.notifier.data.servers)
        server.name,
    },
    BackupSection.knowledgeBases => {
      for (final base in KnowledgeService.instance.notifier.data.bases)
        base.name,
    },
    BackupSection.agents => {
      for (final profile
          in AgentProfilesService.instance.notifier.data.profiles)
        profile.name,
    },
    BackupSection.projects => {
      for (final project in ProjectsService.instance.notifier.data.projects)
        project.name,
    },
    BackupSection.requirements => {
      for (final requirement
          in RequirementsService.instance.notifier.data.requirements)
        requirement.code,
    },
  };
}

/// Espera a que los nueve catálogos —y los ajustes— estén REALMENTE cargados.
///
/// Serializar o mergear con una carga en vuelo lee listas vacías: el
/// respaldo saldría vacío y pisaría el bueno. Los ajustes entran en la
/// espera porque [catalogAsJson] los consulta: sin ellos no sabe dónde está
/// el vault, y toda base de saber que vive adentro saldría exportada como si
/// estuviera afuera. Todo camino de export/import pasa por acá antes de
/// tocar nada.
Future<void> awaitCatalogsReady() => Future.wait([
  SettingsService.instance.notifier.ready,
  SkillsService.instance.notifier.ready,
  RulesService.instance.notifier.ready,
  HooksService.instance.notifier.ready,
  ToolsService.instance.notifier.ready,
  WorkflowsService.instance.notifier.ready,
  McpServersService.instance.notifier.ready,
  AgentProfilesService.instance.notifier.ready,
  KnowledgeService.instance.notifier.ready,
  ProjectsService.instance.notifier.ready,
  RequirementsService.instance.notifier.ready,
]);

/// Si el sistema está vacío de verdad: nada que un respaldo pueda pisar.
///
/// El mapa y el perfil de Keel AI no cuentan — se resiembran en cada
/// arranque, así que una instalación recién puesta ya los tiene y mirarlos
/// diría "acá hay cosas" sobre un sistema en el que no hay nada del usuario.
///
/// De esto depende que restaurar pueda ocurrir sin preguntar: con el sistema
/// vacío no hay nada que perder, y en cuanto hay algo, restaurar vuelve a
/// ser una decisión con preview.
bool catalogIsEmpty() {
  for (final section in BackupSection.values) {
    final names = existingCatalogNames(section)
      ..remove(kKeelAiSkillNameForExport)
      ..remove(kKeelAiHandle);
    if (names.isNotEmpty) return false;
  }
  return true;
}
