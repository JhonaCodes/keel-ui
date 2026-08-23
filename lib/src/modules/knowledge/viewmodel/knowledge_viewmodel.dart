import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_document.dart';
import 'package:keel_ui/src/modules/knowledge/repository/knowledge_bases_repository.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Carpetas que nunca son documentación y sí son enormes. Una base local
/// puede apuntar a un repo entero: sin este filtro el árbol se llena de
/// `node_modules` y el índice tarda segundos en armarse.
const _skippedDirectories = {
  '.git',
  'node_modules',
  'build',
  '.dart_tool',
  '.idea',
  '.vscode',
  'Pods',
  'DerivedData',
  '__pycache__',
};

/// Tope de archivos por base. Existe para que apuntar una base a la carpeta
/// equivocada sea molesto y no un cuelgue: se corta, se avisa, y el usuario
/// corrige la ruta.
const _maxIndexedFiles = 5000;

class KnowledgeState {
  final List<KnowledgeBase> bases;

  /// El estado en disco de cada base, por id. Se arma escaneando; nunca se
  /// persiste, porque la fuente de verdad es el disco.
  final Map<String, KnowledgeIndex> indexes;

  /// Ids de las bases con una sincronización corriendo ahora.
  final Set<String> syncing;

  final KnowledgeDocument? selectedDocument;
  final String status;

  const KnowledgeState({
    this.bases = const [],
    this.indexes = const {},
    this.syncing = const {},
    this.selectedDocument,
    this.status = '',
  });

  KnowledgeState copyWith({
    List<KnowledgeBase>? bases,
    Map<String, KnowledgeIndex>? indexes,
    Set<String>? syncing,
    KnowledgeDocument? selectedDocument,
    bool clearSelection = false,
    String? status,
  }) {
    return KnowledgeState(
      bases: bases ?? this.bases,
      indexes: indexes ?? this.indexes,
      syncing: syncing ?? this.syncing,
      selectedDocument: clearSelection
          ? null
          : selectedDocument ?? this.selectedDocument,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeState &&
          runtimeType == other.runtimeType &&
          listEquals(bases, other.bases) &&
          mapEquals(indexes, other.indexes) &&
          setEquals(syncing, other.syncing) &&
          selectedDocument == other.selectedDocument &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(bases),
    Object.hashAll(
      indexes.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(syncing),
    selectedDocument,
    status,
  );

  @override
  String toString() =>
      'KnowledgeState(bases: ${bases.length}, syncing: ${syncing.length}, '
      'selected: ${selectedDocument?.relativePath})';
}

/// El área de Saber: bases de documentación con frontera de contexto. Una
/// proyecto (o un perfil oráculo) declara qué bases ve por nombre, y en el
/// turno de sus agentes entra el MAPA de esas bases — nunca los documentos
/// enteros. Ver `docs/features/16-bases-de-saber.md`.
class KnowledgeViewModel extends ViewModel<KnowledgeState> {
  KnowledgeViewModel() : super(const KnowledgeState());

  KnowledgeBasesRepository get _repository => KnowledgeBasesRepository();

  /// Application Support resuelto una vez, para que [rootPathOf] sea
  /// síncrono: el armado del turno de un agente no puede esperar I/O.
  static String _supportPath = '';

  Future<void>? _ready;

  /// Resuelve cuando el CATÁLOGO de bases cargó. Es lo que espera el
  /// arranque, y es todo lo que la UI necesita para dibujar la lista.
  Future<void> get ready => _ready ??= _load();

  Completer<void>? _indexed;

  /// Resuelve cuando el ÍNDICE terminó de armarse — que es otra cosa.
  ///
  /// Armar el índice recorre el disco de cada base con `listSync`, y con
  /// una docena de repos grandes son miles de entradas. Mientras eso estaba
  /// pegado a [ready], el arranque entero esperaba a que se recorrieran
  /// `/Volumes/Data` enteros antes de dejar ver la app.
  ///
  /// Lo espera quien necesita el MAPA: el armado del turno de un agente.
  /// Ahí sí tiene sentido, porque sin mapa el agente no ve las bases.
  Future<void> get indexReady async {
    await ready;
    await (_indexed ??= Completer<void>()).future;
  }

  @override
  void init() {
    if (_ready == null) updateSilently(const KnowledgeState());
    unawaited(ready);
  }

  Future<void> _load() async {
    try {
      _supportPath = (await getApplicationSupportDirectory()).path;
      final bases = await _migrated(await _repository.load());
      updateState(data.copyWith(bases: bases));
      // El índice arranca solo y no frena a nadie.
      unawaited(_indexInBackground(bases));
    } catch (error) {
      Log.e('Failed to load knowledge bases', error: error);
      (_indexed ??= Completer<void>()).complete();
    }
  }

  Future<void> _indexInBackground(List<KnowledgeBase> bases) async {
    final completer = _indexed ??= Completer<void>();
    try {
      await _reindexAll(bases);
    } catch (error) {
      Log.e('Failed to index knowledge bases', error: error);
    } finally {
      if (!completer.isCompleted) completer.complete();
    }
  }

  /// Una sola vez: la URL única de la vieja sección Conocimiento (F11) pasa
  /// a ser una base, y el ajuste queda en blanco. Sin bases registradas y
  /// sin URL no hace nada, que es el caso de una instalación nueva.
  Future<List<KnowledgeBase>> _migrated(List<KnowledgeBase> bases) async {
    if (bases.isNotEmpty) return bases;

    final settings = SettingsService.instance.notifier;
    await settings.ready;
    final legacyUrl = settings.data.knowledgeRepoUrl.trim();
    if (legacyUrl.isEmpty) return bases;

    final migrated = [
      KnowledgeBase(
        id: generateUuidV4(),
        name: 'conocimiento',
        description: 'Documentación migrada de la sección anterior.',
        source: KnowledgeSource.git,
        gitUrl: legacyUrl,
        createdAt: DateTime.now(),
      ),
    ];
    await _repository.save(migrated);
    settings.setKnowledgeRepoUrl('');
    Log.i('Knowledge: migrada la URL única a la base "conocimiento"');
    return migrated;
  }

  // ── catálogo ────────────────────────────────────────────────────────

  /// Registra una base. Devuelve un mensaje de error para mostrar, o null.
  ///
  /// [createFolderIfMissing] existe para el camino de las tools: cuando un
  /// agente arma una base local para escribir documentación adentro, la
  /// carpeta todavía no existe y exigirla sería pedirle al usuario que la
  /// cree a mano. Desde el formulario queda en false: ahí una ruta que no
  /// existe es un error de tipeo, y crear la carpeta lo escondería.
  String? createBase({
    required String name,
    required String description,
    required KnowledgeSource source,
    String gitUrl = '',
    String gitBranch = '',
    String localPath = '',
    bool createFolderIfMissing = false,
  }) {
    if (createFolderIfMissing &&
        source == KnowledgeSource.local &&
        localPath.trim().isNotEmpty) {
      try {
        Directory(localPath.trim()).createSync(recursive: true);
      } catch (error) {
        return 'No pude crear la carpeta: $error';
      }
    }

    final error = _validate(
      name,
      source: source,
      gitUrl: gitUrl,
      localPath: localPath,
    );
    if (error != null) return error;

    final base = KnowledgeBase(
      id: generateUuidV4(),
      name: name,
      description: description.trim(),
      source: source,
      gitUrl: gitUrl.trim(),
      gitBranch: gitBranch.trim(),
      localPath: localPath.trim(),
      createdAt: DateTime.now(),
    );
    final bases = [...data.bases, base];
    updateState(data.copyWith(bases: bases));
    unawaited(_repository.save(bases));
    unawaited(reindexBase(base.id));
    return null;
  }

  String? updateBase(
    String id, {
    required String name,
    required String description,
    required KnowledgeSource source,
    String gitUrl = '',
    String gitBranch = '',
    String localPath = '',
  }) {
    final error = _validate(
      name,
      excludingId: id,
      source: source,
      gitUrl: gitUrl,
      localPath: localPath,
    );
    if (error != null) return error;

    final bases = data.bases
        .map(
          (base) => base.id == id
              ? base.copyWith(
                  name: name,
                  description: description.trim(),
                  source: source,
                  gitUrl: gitUrl.trim(),
                  gitBranch: gitBranch.trim(),
                  localPath: localPath.trim(),
                )
              : base,
        )
        .toList();
    updateState(data.copyWith(bases: bases));
    unawaited(_repository.save(bases));
    unawaited(reindexBase(id));
    return null;
  }

  void deleteBase(String id) {
    final bases = data.bases.where((base) => base.id != id).toList();
    final indexes = {...data.indexes}..remove(id);
    final clearing = data.selectedDocument?.baseId == id;
    updateState(
      data.copyWith(bases: bases, indexes: indexes, clearSelection: clearing),
    );
    unawaited(_repository.save(bases));
  }

  /// Le da carpeta a una base local que llegó sin una (importada). El
  /// contenido no se toca: la base pasa a apuntar ahí y se reindexa.
  String? setBaseFolder(String id, String path) {
    final base = baseById(id);
    if (base == null) return 'Esa base ya no existe.';
    return updateBase(
      id,
      name: base.name,
      description: base.description,
      source: base.source,
      gitUrl: base.gitUrl,
      gitBranch: base.gitBranch,
      localPath: path,
    );
  }

  String? _validate(
    String name, {
    String? excludingId,
    required KnowledgeSource source,
    required String gitUrl,
    required String localPath,
  }) {
    final formatError = validateKnowledgeBaseName(name);
    if (formatError != null) return formatError;

    final isTaken = data.bases.any(
      (base) => base.name == name && base.id != excludingId,
    );
    if (isTaken) return 'Ya existe una base con ese nombre.';

    if (source == KnowledgeSource.git && gitUrl.trim().isEmpty) {
      return 'Una base git necesita la URL del repo.';
    }
    if (source == KnowledgeSource.local && localPath.trim().isNotEmpty) {
      if (!Directory(localPath.trim()).existsSync()) {
        return 'Esa carpeta no existe.';
      }
    }
    return null;
  }

  // ── lecturas ────────────────────────────────────────────────────────

  KnowledgeBase? baseById(String id) =>
      data.bases.where((base) => base.id == id).firstOrNull;

  KnowledgeBase? baseByName(String name) =>
      data.bases.where((base) => base.name == name).firstOrNull;

  /// Dónde vive el contenido de [base]: el espejo en Application Support si
  /// es git, la carpeta del usuario si es local. Vacío si todavía no tiene.
  String rootPathOf(KnowledgeBase base) {
    if (base.source == KnowledgeSource.local) return base.localPath.trim();
    if (_supportPath.isEmpty) return '';
    return '$_supportPath/knowledge/${base.name}';
  }

  KnowledgeIndex? indexOf(String baseId) => data.indexes[baseId];

  // ── índice ──────────────────────────────────────────────────────────

  Future<void> _reindexAll(List<KnowledgeBase> bases) async {
    final indexes = {...data.indexes};
    for (final base in bases) {
      indexes[base.id] = await _buildIndex(base);
    }
    updateState(data.copyWith(indexes: indexes));
  }

  Future<void> reindexBase(String id) async {
    final base = baseById(id);
    if (base == null) return;
    final index = await _buildIndex(base);
    updateState(data.copyWith(indexes: {...data.indexes, id: index}));
  }

  Future<KnowledgeIndex> _buildIndex(KnowledgeBase base) async {
    final root = rootPathOf(base);
    if (root.isEmpty) {
      return const KnowledgeIndex(
        rootPath: '',
        problem: 'Sin carpeta asignada todavía.',
      );
    }
    final directory = Directory(root);
    if (!directory.existsSync()) {
      return KnowledgeIndex(
        rootPath: root,
        problem: base.source == KnowledgeSource.git
            ? 'Sin descargar todavía — tocá Actualizar.'
            : 'La carpeta no existe: $root',
      );
    }

    try {
      // A otro isolate: recorrer hasta 5000 entradas con un `stat` cada una
      // no puede pasar entre frame y frame.
      final scan = await runOffThread(scanKnowledgeTree, root);
      return KnowledgeIndex(
        rootPath: root,
        nodes: scan.nodes,
        indexContent: scan.indexContent,
        problem: scan.truncated
            ? 'Más de $_maxIndexedFiles archivos: el árbol está recortado. '
                  'Apuntá la base a una carpeta más chica.'
            : '',
      );
    } catch (error) {
      Log.e('Knowledge: no pude indexar ${base.name}', error: error);
      return KnowledgeIndex(rootPath: root, problem: 'No pude leerla: $error');
    }
  }

  /// Escaneo recursivo, ordenado carpetas-primero-y-alfabético, saltando lo
  /// que nunca es documentación. Las carpetas que quedan vacías después del
  /// filtro no se listan.
  // ── sincronización ──────────────────────────────────────────────────

  /// Actualiza una base git (clone o pull) y la reindexa. Una base local no
  /// tiene nada que sincronizar: se reindexa y ya.
  Future<String> syncBase(String id) =>
      AppStatusService.instance.notifier
      // Avisa, no bloquea: traer un `git pull` y rearmar un índice no pisa
      // nada de lo que estés haciendo, y atenuar la app por eso enseña a
      // ignorar el aviso justo cuando sí importa —restaurar un respaldo.
      .inBackground('Actualizando una base de saber', () => _syncBase(id));

  Future<String> _syncBase(String id) async {
    final base = baseById(id);
    if (base == null) return 'Esa base ya no existe.';
    if (data.syncing.contains(id)) {
      return 'La base "${base.name}" ya se está actualizando.';
    }

    if (base.source == KnowledgeSource.local) {
      await reindexBase(id);
      final count = indexOf(id)?.documentCount ?? 0;
      final message = 'Base "${base.name}": $count documentos.';
      updateState(data.copyWith(status: message));
      return message;
    }

    updateState(
      data.copyWith(
        syncing: {...data.syncing, id},
        status: 'Actualizando "${base.name}"…',
      ),
    );
    try {
      final message = await _pullOrClone(base);
      await reindexBase(id);
      updateState(
        data.copyWith(syncing: {...data.syncing}..remove(id), status: message),
      );
      return message;
    } catch (error) {
      final message = 'Base "${base.name}": $error';
      Log.e('Knowledge sync failed for ${base.name}', error: error);
      updateState(
        data.copyWith(syncing: {...data.syncing}..remove(id), status: message),
      );
      return message;
    }
  }

  Future<String> syncAll() async {
    final messages = <String>[];
    for (final base in data.bases) {
      messages.add(await syncBase(base.id));
    }
    final summary = messages.isEmpty
        ? 'No hay bases de saber registradas.'
        : messages.join('\n');
    updateState(data.copyWith(status: summary));
    return summary;
  }

  Future<String> _pullOrClone(KnowledgeBase base) async {
    final root = rootPathOf(base);
    if (root.isEmpty) throw 'no pude resolver su carpeta.';

    final hasClone = Directory('$root/.git').existsSync();
    if (hasClone) {
      final remote = await _git([
        'remote',
        'set-url',
        'origin',
        base.gitUrl,
      ], cwd: root);
      if (!remote.ok) Log.w('knowledge remote set-url: ${remote.output}');
      final pull = await _git(['pull', '--ff-only'], cwd: root);
      if (!pull.ok) throw 'git pull falló: ${pull.output}';
    } else {
      await Directory(root).parent.create(recursive: true);
      final clone = await _git([
        'clone',
        '--depth',
        '1',
        if (base.gitBranch.isNotEmpty) ...['--branch', base.gitBranch],
        base.gitUrl,
        root,
      ]);
      if (!clone.ok) throw 'git clone falló: ${clone.output}';
    }
    return 'Base "${base.name}" al día.';
  }

  Future<({bool ok, String output})> _git(
    List<String> args, {
    String? cwd,
  }) async {
    final result = await Process.run('git', args, workingDirectory: cwd);
    final output = [
      (result.stdout as String).trim(),
      (result.stderr as String).trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    return (ok: result.exitCode == 0, output: output);
  }

  // ── documento abierto ───────────────────────────────────────────────

  Future<void> selectDocument(String baseId, String relativePath) async {
    final base = baseById(baseId);
    if (base == null) return;
    final absolute = '${rootPathOf(base)}/$relativePath';
    final kind = KnowledgeDocument.kindOf(relativePath);

    var text = '';
    var problem = '';
    if (KnowledgeDocument(
      baseId: baseId,
      relativePath: relativePath,
      absolutePath: absolute,
      kind: kind,
    ).isText) {
      try {
        text = await File(absolute).readAsString();
      } catch (error) {
        problem = 'No pude leerlo: $error';
      }
    }

    updateState(
      data.copyWith(
        selectedDocument: KnowledgeDocument(
          baseId: baseId,
          relativePath: relativePath,
          absolutePath: absolute,
          kind: kind,
          text: text,
          problem: problem,
        ),
      ),
    );
  }

  void clearSelection() => updateState(data.copyWith(clearSelection: true));

  /// Abre [absolutePath] con la app que el sistema tenga asociada. Es la
  /// salida para los formatos que esta app no dibuja (PDF, planillas): se
  /// delega en vez de fingir un visor.
  Future<void> openWithSystem(String absolutePath) async {
    final result = await Process.run('open', [absolutePath]);
    if (result.exitCode == 0) return;
    final message = 'No pude abrirlo: ${(result.stderr as String).trim()}';
    Log.w('Knowledge open failed for $absolutePath');
    updateState(data.copyWith(status: message));
  }

  // ── lo que ve un agente ─────────────────────────────────────────────

  /// El MAPA de las bases [baseNames], para inyectar en el turno de un
  /// agente. Tamaño acotado: raíz, cuántos documentos, las carpetas de
  /// primer nivel y la portada `INDEX.md` si la base tiene una. Los
  /// documentos los abre el agente con sus propias herramientas — de eso se
  /// trata: que sepa dónde y qué consultar, no que se lo cargue entero.
  ///
  /// Devuelve vacío si no hay ninguna base resoluble, para que quien lo
  /// llama no agregue un encabezado colgado.
  String briefFor(List<String> baseNames) {
    final buffer = StringBuffer();

    for (final name in baseNames) {
      final base = baseByName(name);
      if (base == null) {
        Log.w('Base de saber "$name" referenciada y no registrada');
        continue;
      }
      final index = indexOf(base.id);
      final root = rootPathOf(base);
      if (index == null || root.isEmpty || index.isEmpty) continue;

      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(
        'Base de saber "${base.name}"'
        '${base.description.isEmpty ? '' : ' — ${base.description}'}',
      );
      buffer.writeln('Raíz: $root  (${index.documentCount} documentos)');

      final folders = index.nodes.where((node) => node.isDirectory).toList();
      if (folders.isNotEmpty) {
        buffer.writeln(
          folders
              .map((folder) => '${folder.name}/ (${folder.documentCount})')
              .join(' · '),
        );
      }
      if (index.indexContent.isNotEmpty) {
        buffer.writeln('--- portada de ${base.name} ---');
        buffer.writeln(index.indexContent.trim());
        buffer.writeln('--- fin ---');
      }
    }

    if (buffer.isEmpty) return '';
    return '''
Tenés estas bases de saber disponibles. Buscá en ellas con Grep/Read cuando
necesites un dato del proyecto; no las leas enteras.

${buffer.toString().trim()}''';
  }
}

mixin KnowledgeService {
  static final ReactiveNotifier<KnowledgeViewModel> instance =
      ReactiveNotifier<KnowledgeViewModel>(() => KnowledgeViewModel());
}

/// Lo que sale de mirar la carpeta de una base: el árbol, su portada y si
/// hubo que recortar.
typedef KnowledgeScan = ({
  List<KnowledgeNode> nodes,
  String indexContent,
  bool truncated,
});

/// Recorre la carpeta de una base y arma su árbol. **Corre en otro isolate.**
///
/// Es de nivel superior a propósito: hasta 5000 entradas de `listSync` con un
/// `stat` cada una es medio segundo largo en un repo grande, y eso en el hilo
/// de la interfaz son frames perdidos justo mientras alguien escribe.
KnowledgeScan scanKnowledgeTree(String root) {
  var budget = _maxIndexedFiles;
  final nodes = _scanTree(
    Directory(root),
    root,
    () => budget,
    (used) => budget = used,
  );

  var portada = '';
  for (final candidate in kKnowledgeIndexFileNames) {
    final file = File('$root/$candidate');
    if (!file.existsSync()) continue;
    portada = file.readAsStringSync();
    break;
  }

  return (
    nodes: nodes,
    indexContent: portada.length > kKnowledgeIndexPromptLimit
        ? '${portada.substring(0, kKnowledgeIndexPromptLimit)}\n…'
        : portada,
    truncated: budget <= 0,
  );
}

List<KnowledgeNode> _scanTree(
  Directory directory,
  String root,
  int Function() budget,
  void Function(int) spend,
) {
  final entities = directory.listSync()
    ..sort((a, b) => a.path.compareTo(b.path));
  final directories = <KnowledgeNode>[];
  final files = <KnowledgeNode>[];

  for (final entity in entities) {
    final name = entity.path.split('/').last;
    if (name.startsWith('.')) continue;

    if (entity is Directory) {
      if (_skippedDirectories.contains(name)) continue;
      // El tope corta TAMBIÉN acá. Estando solo en la rama de archivos, un
      // árbol grande se seguía recorriendo entero aunque el presupuesto ya
      // estuviera agotado: se pagaba el `listSync` de todo para después
      // tirarlo.
      if (budget() <= 0) break;
      final children = _scanTree(entity, root, budget, spend);
      if (children.isEmpty) continue;
      directories.add(
        KnowledgeNode(
          name: name,
          relativePath: entity.path.substring(root.length + 1),
          isDirectory: true,
          children: children,
        ),
      );
      continue;
    }

    if (entity is! File) continue;
    if (budget() <= 0) break;
    spend(budget() - 1);
    files.add(
      KnowledgeNode(
        name: name,
        relativePath: entity.path.substring(root.length + 1),
        isDirectory: false,
      ),
    );
  }

  return [...directories, ...files];
}
