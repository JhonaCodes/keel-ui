part of '../catalog_backup.dart';

class CatalogBackupState {
  final bool busy;
  final String log;

  /// Ruta del archivo inspeccionado, o null si no hay uno cargado.
  final String? loadedPath;
  final BackupPreview? preview;

  const CatalogBackupState({
    this.busy = false,
    this.log = '',
    this.loadedPath,
    this.preview,
  });

  CatalogBackupState copyWith({
    bool? busy,
    String? log,
    String? loadedPath,
    BackupPreview? preview,
    bool clearLoaded = false,
  }) {
    return CatalogBackupState(
      busy: busy ?? this.busy,
      log: log ?? this.log,
      loadedPath: clearLoaded ? null : (loadedPath ?? this.loadedPath),
      preview: clearLoaded ? null : (preview ?? this.preview),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogBackupState &&
          runtimeType == other.runtimeType &&
          busy == other.busy &&
          log == other.log &&
          loadedPath == other.loadedPath &&
          preview == other.preview;

  @override
  int get hashCode => Object.hash(busy, log, loadedPath, preview);

  @override
  String toString() => 'CatalogBackupState(busy: $busy, loaded: $loadedPath)';
}

/// Export/import del catálogo a UN archivo, con selección por secciones.
///
/// Reusa la forma portable de `catalog_sync` ([catalogAsJson] /
/// [mergeCatalogJson]) — dos destinos, una forma — y le suma lo que el
/// mirror git nunca lleva: los DOCUMENTOS de las bases de saber locales, y
/// los secrets cuando el usuario los pide explícitamente.
class CatalogBackupViewModel extends ViewModel<CatalogBackupState> {
  CatalogBackupViewModel() : super(const CatalogBackupState());

  /// El archivo inspeccionado, entero, para aplicar después sin releerlo.
  Map<String, dynamic>? _loaded;

  @override
  void init() {
    updateSilently(const CatalogBackupState());
  }

  /// Un documento de saber más grande que esto no viaja: el respaldo es de
  /// catálogo y conocimiento, no de binarios.
  static const _maxDocBytes = 262144;

  // ── export ──────────────────────────────────────────────────────────

  /// Arma el respaldo con [sections] (+ secrets si [includeSecrets]) y lo
  /// escribe donde el usuario elija. El resultado queda en [CatalogBackupState.log].
  Future<void> exportBackup({
    required Set<BackupSection> sections,
    required bool includeSecrets,
  }) async {
    if (data.busy) return;
    updateState(data.copyWith(busy: true, log: ''));
    try {
      final catalog = catalogAsJson();
      final selected = {
        for (final section in sections)
          if ((catalog[section.category] ?? const []).isNotEmpty)
            section.category: catalog[section.category]!,
      };

      final knowledgeDocs = sections.contains(BackupSection.knowledgeBases)
          ? _collectKnowledgeDocs()
          : const <String, Map<String, String>>{};

      final secrets = includeSecrets
          ? [
              for (final secret
                  in SecretsService.instance.notifier.data.secrets)
                {
                  'name': secret.name,
                  'description': secret.description,
                  'value': secret.value,
                },
            ]
          : const <Map<String, dynamic>>[];

      final stamp = DateTime.now();
      final location = await getSaveLocation(
        suggestedName:
            'keel-respaldo-${stamp.year}'
            '${stamp.month.toString().padLeft(2, '0')}'
            '${stamp.day.toString().padLeft(2, '0')}.json',
      );
      if (location == null) {
        updateState(data.copyWith(busy: false, log: 'Export cancelado.'));
        return;
      }

      final payload = <String, dynamic>{
        'keelBackup': kBackupFormatVersion,
        'createdAt': stamp.toIso8601String(),
        'catalog': selected,
        if (knowledgeDocs.isNotEmpty) 'knowledgeDocs': knowledgeDocs,
        if (secrets.isNotEmpty) 'secrets': secrets,
      };
      await File(
        location.path,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      final total = selected.values.fold(0, (sum, list) => sum + list.length);
      final docs = knowledgeDocs.values.fold(
        0,
        (sum, files) => sum + files.length,
      );
      updateState(
        data.copyWith(
          busy: false,
          log:
              'Exporté $total elementos'
              '${docs == 0 ? '' : ', $docs documentos de saber'}'
              '${secrets.isEmpty ? '' : ', ${secrets.length} secrets (¡el archivo lleva sus valores en texto plano!)'}'
              ' a ${location.path}.',
        ),
      );
    } catch (error) {
      Log.e('Backup export failed', error: error);
      updateState(data.copyWith(busy: false, log: 'El export falló: $error'));
    }
  }

  /// Los documentos de cada base LOCAL con carpeta: ruta relativa →
  /// contenido. Una base git no viaja — su contenido se recupera clonando.
  Map<String, Map<String, String>> _collectKnowledgeDocs() {
    final docs = <String, Map<String, String>>{};
    for (final base in KnowledgeService.instance.notifier.data.bases) {
      if (base.source != KnowledgeSource.local) continue;
      final root = base.localPath.trim();
      if (root.isEmpty) continue;
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      final files = <String, String>{};
      final prefix = root.endsWith('/') ? root : '$root/';
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.startsWith(prefix)) continue;
        final relative = entity.path.substring(prefix.length);
        // Ocultos (.git y compañía) afuera, igual que del índice de saber.
        if (relative.startsWith('.') || relative.contains('/.')) continue;
        if (entity.lengthSync() > _maxDocBytes) continue;
        try {
          files[relative] = entity.readAsStringSync();
        } catch (_) {
          // Binario o encoding roto: no es un documento.
          continue;
        }
      }
      if (files.isNotEmpty) docs[base.name] = files;
    }
    return docs;
  }

  // ── import ──────────────────────────────────────────────────────────

  /// Abre un archivo de respaldo y arma el PREVIEW: qué trae y qué pisaría.
  /// No aplica nada — eso es [applyLoaded], después de que el usuario elija.
  Future<void> pickAndInspect() async {
    if (data.busy) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Respaldo de keel', extensions: ['json']),
      ],
    );
    if (file == null) return;

    updateState(data.copyWith(busy: true, log: ''));
    try {
      final parsed =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (parsed['keelBackup'] is! int) {
        updateState(
          data.copyWith(
            busy: false,
            log: 'Ese archivo no es un respaldo de keel.',
            clearLoaded: true,
          ),
        );
        return;
      }
      _loaded = parsed;
      updateState(
        data.copyWith(
          busy: false,
          loadedPath: file.path,
          preview: _previewOf(parsed),
        ),
      );
    } catch (error) {
      Log.e('Backup inspect failed', error: error);
      updateState(
        data.copyWith(
          busy: false,
          log: 'No pude leer el archivo: $error',
          clearLoaded: true,
        ),
      );
    }
  }

  BackupPreview _previewOf(Map<String, dynamic> parsed) {
    final catalog = (parsed['catalog'] as Map?)?.cast<String, dynamic>() ?? {};
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
      final existing = _existingNamesOf(section);
      conflicts[section] = inFile
          .where((name) => existing.contains(name))
          .toList();
    }

    final docs = (parsed['knowledgeDocs'] as Map?)?.cast<String, dynamic>();
    final secretList = (parsed['secrets'] as List?) ?? const [];
    return BackupPreview(
      names: names,
      conflicts: conflicts,
      knowledgeDocCounts: {
        for (final entry in (docs ?? const {}).entries)
          entry.key: (entry.value as Map?)?.length ?? 0,
      },
      secretCount: secretList.length,
      secretsWithValue: secretList
          .where(
            (secret) =>
                secret is Map && (secret['value'] as String? ?? '').isNotEmpty,
          )
          .length,
    );
  }

  Set<String> _existingNamesOf(BackupSection section) {
    return switch (section) {
      BackupSection.skills => {
        for (final skill in SkillsService.instance.notifier.data.skills)
          skill.name,
      },
      BackupSection.rules => {
        for (final rule in RulesService.instance.notifier.data.rules) rule.name,
      },
      BackupSection.tools => {
        for (final tool in ToolsService.instance.notifier.data.tools) tool.name,
      },
      BackupSection.workflows => {
        for (final workflow
            in WorkflowsService.instance.notifier.data.workflows)
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
      BackupSection.stations => {
        for (final station in StationsService.instance.notifier.data.stations)
          station.name,
      },
    };
  }

  /// Aplica el archivo ya inspeccionado: solo las [sections] elegidas, y los
  /// secrets solo si [includeSecrets]. Merge por nombre, como el catálogo.
  Future<void> applyLoaded({
    required Set<BackupSection> sections,
    required bool includeSecrets,
  }) async {
    final loaded = _loaded;
    if (loaded == null || data.busy) return;
    updateState(data.copyWith(busy: true, log: ''));
    try {
      final catalog =
          (loaded['catalog'] as Map?)?.cast<String, dynamic>() ?? {};
      final byCategory = {
        for (final section in sections)
          if (catalog[section.category] is List)
            section.category: [
              for (final json in catalog[section.category] as List)
                if (json is Map) json.cast<String, dynamic>(),
            ],
      };

      final parts = <String>[];
      if (byCategory.isNotEmpty) {
        parts.add(await mergeCatalogJson(byCategory));
      }
      if (sections.contains(BackupSection.knowledgeBases)) {
        final docsSummary = await _applyKnowledgeDocs(loaded);
        if (docsSummary.isNotEmpty) parts.add(docsSummary);
      }
      if (includeSecrets) {
        parts.add(_applySecrets(loaded));
      }
      updateState(
        data.copyWith(
          busy: false,
          log: parts.isEmpty ? 'No había nada que aplicar.' : parts.join('\n'),
        ),
      );
    } catch (error) {
      Log.e('Backup apply failed', error: error);
      updateState(data.copyWith(busy: false, log: 'El import falló: $error'));
    }
  }

  /// Escribe los documentos del archivo en las bases que tengan carpeta en
  /// ESTA máquina. Las rutas nunca viajan, así que una base recién importada
  /// no tiene dónde recibirlos — se dice, no se inventa una ruta.
  Future<String> _applyKnowledgeDocs(Map<String, dynamic> loaded) async {
    final docs = (loaded['knowledgeDocs'] as Map?)?.cast<String, dynamic>();
    if (docs == null || docs.isEmpty) return '';

    final knowledge = KnowledgeService.instance.notifier;
    var written = 0;
    final notes = <String>[];

    for (final entry in docs.entries) {
      final base = knowledge.data.bases
          .where((base) => base.name == entry.key)
          .firstOrNull;
      final files = (entry.value as Map?)?.cast<String, dynamic>() ?? {};
      if (base == null) {
        notes.add(
          'la base "${entry.key}" no existe acá (importá la sección Bases '
          'de saber)',
        );
        continue;
      }
      if (base.source != KnowledgeSource.local) {
        notes.add('la base "${entry.key}" es git: su contenido viene del repo');
        continue;
      }
      if (base.localPath.trim().isEmpty) {
        notes.add(
          'la base "${entry.key}" no tiene carpeta en esta máquina: '
          'asignale una y volvé a importar',
        );
        continue;
      }
      final root = base.localPath.trim();
      for (final doc in files.entries) {
        final content = doc.value;
        if (content is! String) continue;
        // La ruta relativa no puede escaparse de la raíz de la base.
        if (doc.key.contains('..')) continue;
        final file = File('$root/${doc.key}');
        await file.create(recursive: true);
        await file.writeAsString(content);
        written++;
      }
      unawaited(knowledge.reindexBase(base.id));
    }

    return [
      if (written > 0) 'Escribí $written documentos de saber.',
      if (notes.isNotEmpty) 'Saber sin aplicar: ${notes.join('; ')}.',
    ].join('\n');
  }

  /// Crea los secrets que falten y completa el valor SOLO de los que acá
  /// están pendientes. Un secret local con valor nunca se pisa desde un
  /// archivo — eso se hace a mano, viendo lo que se reemplaza.
  String _applySecrets(Map<String, dynamic> loaded) {
    final incoming = (loaded['secrets'] as List?) ?? const [];
    if (incoming.isEmpty) return 'El archivo no trae secrets.';

    final secrets = SecretsService.instance.notifier;
    var created = 0;
    var filled = 0;
    var skipped = 0;

    for (final raw in incoming) {
      if (raw is! Map) continue;
      final name = raw['name'] as String? ?? '';
      final value = raw['value'] as String? ?? '';
      final description = raw['description'] as String? ?? '';
      if (name.isEmpty) continue;

      final existing = secrets.data.secrets
          .where((secret) => secret.name == name)
          .firstOrNull;
      if (existing == null) {
        final error = secrets.createSecret(
          name: name,
          description: description,
          value: value,
        );
        if (error == null) created++;
      } else if (existing.isPending && value.isNotEmpty) {
        final error = secrets.updateSecret(
          existing.id,
          name: existing.name,
          description: existing.description.isEmpty
              ? description
              : existing.description,
          value: value,
        );
        if (error == null) filled++;
      } else {
        skipped++;
      }
    }
    return 'Secrets: $created creados, $filled completados'
        '${skipped == 0 ? '.' : ', $skipped sin tocar (ya tenían valor).'}';
  }
}

mixin CatalogBackupService {
  static final ReactiveNotifier<CatalogBackupViewModel> instance =
      ReactiveNotifier<CatalogBackupViewModel>(() => CatalogBackupViewModel());
}
