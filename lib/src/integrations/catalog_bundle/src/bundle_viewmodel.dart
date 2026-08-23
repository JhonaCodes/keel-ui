part of '../catalog_bundle.dart';

/// De dónde salió el paquete que se está mirando.
enum BundleSource { file, link }

/// Lo que está por salir: qué se lleva, qué le falta, y la misma revisión
/// que va a ver el que lo reciba.
class BundleDraft {
  const BundleDraft({
    required this.manifest,
    required this.closure,
    required this.audit,
  });

  final BundleManifest manifest;
  final BundleClosure closure;

  /// Sí, al que exporta también. Es la única oportunidad de enterarte de que
  /// tu tool lleva tu carpeta personal adentro ANTES de mandársela a otro —
  /// después ya viajó.
  final BundleAudit audit;
}

class BundleState {
  const BundleState({
    this.busy = false,
    this.log = '',
    this.draft,
    this.review,
    this.source,
    this.sourceLabel = '',
  });

  final bool busy;
  final String log;

  /// El paquete propio a punto de escribirse.
  final BundleDraft? draft;

  /// Lo abierto y revisado, esperando que alguien decida. Null = no hay
  /// nada cargado y la pantalla pide un archivo o un enlace.
  final BundleReview? review;

  final BundleSource? source;
  final String sourceLabel;

  BundleState copyWith({
    bool? busy,
    String? log,
    BundleDraft? draft,
    BundleReview? review,
    BundleSource? source,
    String? sourceLabel,
    bool clearDraft = false,
    bool clearReview = false,
  }) => BundleState(
    busy: busy ?? this.busy,
    log: log ?? this.log,
    draft: clearDraft ? null : (draft ?? this.draft),
    review: clearReview ? null : (review ?? this.review),
    source: clearReview ? null : (source ?? this.source),
    sourceLabel: clearReview ? '' : (sourceLabel ?? this.sourceLabel),
  );
}

/// Exportar una cosa y sus dependencias, y traer la de otro con revisión de
/// por medio.
///
/// El estado es de UN paquete a la vez, a propósito: instalar es una
/// decisión que se toma mirando lo que trae, y una cola de paquetes en
/// revisión es una cola de decisiones que se terminan apretando de corrido.
class BundleViewModel extends ViewModel<BundleState> {
  BundleViewModel() : super(const BundleState());

  @override
  void init() {}

  // ── exportar ────────────────────────────────────────────────────────

  /// Arma el paquete de [name] SIN escribirlo: qué se lleva, qué le falta y
  /// qué encontró la revisión. Escribir es [writeDraft], después de mirar.
  ///
  /// Dos pasos y no uno porque un paquete es para otra persona: lo que sale
  /// de acá lleva prompts, scripts y rutas que uno dejó hace meses y no
  /// recuerda. La lista es la última vez que se puede revisar.
  Future<void> prepare(BundleKind kind, String name) async {
    updateState(const BundleState(busy: true));
    // Los catálogos cargan de disco al arrancar. Sin esperarlos, exportar
    // en los primeros segundos de la app empaqueta la mitad de lo que el
    // agente usa y no lo dice.
    await awaitCatalogsReady();

    final catalog = catalogAsJson();
    final closure = buildBundleClosure(
      kind: kind,
      name: name,
      catalog: catalog,
    );
    final root = closure
        .of(kind.rootCategory)
        .where((json) => json['name'] == name)
        .firstOrNull;
    if (root == null) {
      updateState(
        BundleState(log: 'No encontré ${kind.label} «$name» para exportar.'),
      );
      return;
    }

    final manifest = BundleManifest(
      kind: kind,
      name: name,
      summary: bundleSummaryOf(kind, root),
      exportedAt: DateTime.now(),
      requiredSecrets: requiredSecretsOf(closure),
      counts: closure.counts,
    );

    updateState(
      BundleState(
        draft: BundleDraft(
          manifest: manifest,
          closure: closure,
          audit: auditBundle(
            BundleContents(manifest: manifest, catalog: closure.catalog),
          ),
        ),
      ),
    );
  }

  /// Escribe el borrador donde el usuario elija.
  Future<void> writeDraft() async {
    final draft = data.draft;
    if (draft == null || data.busy) return;
    final manifest = draft.manifest;

    final location = await getSaveLocation(
      suggestedName: bundleFileNameOf(manifest.kind, manifest.name),
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Paquete de keel', extensions: ['zip']),
      ],
    );
    if (location == null) return;

    final job = BundleExportJob(
      destinationPath: location.path,
      manifest: manifest.toJson(),
      catalog: draft.closure.catalog,
      knowledgeRoots: _localRootsOf(draft.closure),
    );

    updateState(data.copyWith(busy: true, log: ''));
    try {
      // Fuera del hilo de la interfaz, como el respaldo: leer carpetas de
      // saber y comprimir no puede trabar lo que estás escribiendo.
      final written = await AppStatusService.instance.notifier.inBackground(
        'Armando el paquete de ${manifest.name}',
        () => runOffThread(writeBundleArchive, job),
      );
      updateState(
        data.copyWith(
          busy: false,
          log: _exportLog(manifest, written, draft.closure, location),
        ),
      );
    } catch (error) {
      Log.e('Bundle export failed', error: error);
      updateState(data.copyWith(busy: false, log: 'El export falló: $error'));
    }
  }

  String _exportLog(
    BundleManifest manifest,
    BundleWritten written,
    BundleClosure closure,
    FileSaveLocation location,
  ) {
    final parts = <String>[
      'Empaqueté ${manifest.kind.label} «${manifest.name}»: '
          '${manifest.entityCount} elementos'
          '${written.documentCount == 0 ? '' : ', ${written.documentCount} documentos'}'
          ' en ${location.path}.',
      if (written.skipped.isNotEmpty)
        'Quedó afuera por tamaño:\n- ${written.skipped.join('\n- ')}',
    ];
    return parts.join('\n');
  }

  /// Las carpetas de las bases LOCALES del paquete que existen en esta
  /// máquina. Una base git no manda documentos: del otro lado se clona.
  Map<String, String> _localRootsOf(BundleClosure closure) {
    final roots = <String, String>{};
    for (final json in closure.of('knowledge_bases')) {
      final name = json['name'] as String? ?? '';
      final base = KnowledgeService.instance.notifier.data.bases
          .where((candidate) => candidate.name == name)
          .firstOrNull;
      if (base == null || base.source != KnowledgeSource.local) continue;
      if (base.localPath.trim().isEmpty) continue;
      roots[name] = base.localPath;
    }
    return roots;
  }

  // ── importar ────────────────────────────────────────────────────────

  Future<void> pickAndReview() async {
    if (data.busy) return;
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Paquete de keel', extensions: ['zip']),
      ],
    );
    if (file == null) return;
    await _review(
      () async => Uint8List.fromList(await file.readAsBytes()),
      source: BundleSource.file,
      label: file.path,
    );
  }

  /// Trae un paquete de un enlace. Es el camino que un catálogo público
  /// usaría, y por eso lo que baja pasa por la MISMA revisión que un archivo
  /// elegido a mano: el origen no cambia lo que hay adentro.
  Future<void> reviewFromLink(String rawUrl) async {
    if (data.busy) return;
    final url = Uri.tryParse(rawUrl.trim());
    if (url == null || !url.hasAuthority || !_isHttp(url)) {
      updateState(
        data.copyWith(log: 'Ese enlace no es una dirección http o https.'),
      );
      return;
    }

    await _review(
      () async {
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw BundleFormatException(
            'El enlace contestó ${response.statusCode}.',
          );
        }
        return Uint8List.fromList(response.bodyBytes);
      },
      source: BundleSource.link,
      label: url.toString(),
    );
  }

  bool _isHttp(Uri url) => url.scheme == 'http' || url.scheme == 'https';

  Future<void> _review(
    Future<Uint8List> Function() fetch, {
    required BundleSource source,
    required String label,
  }) async {
    updateState(data.copyWith(busy: true, log: '', clearReview: true));
    try {
      final bytes = await fetch();
      final review = await AppStatusService.instance.notifier.inBackground(
        'Revisando el paquete',
        () => runOffThread(inspectBundleBytes, bytes),
      );
      updateState(
        data.copyWith(
          busy: false,
          review: review,
          source: source,
          sourceLabel: label,
        ),
      );
    } on BundleFormatException catch (error) {
      updateState(data.copyWith(busy: false, log: error.message));
    } catch (error) {
      Log.e('Bundle inspect failed', error: error);
      updateState(
        data.copyWith(busy: false, log: 'No pude abrir el paquete: $error'),
      );
    }
  }

  void discard() => updateState(const BundleState(log: 'Descarté el paquete.'));

  /// Instala lo que está cargado. Es el MISMO merge que restaurar un
  /// respaldo —crea o actualiza por nombre—, así que no hay un segundo
  /// camino de entrada al catálogo que mantener sincronizado con el primero.
  Future<void> install() async {
    final review = data.review;
    if (review == null || data.busy) return;

    updateState(data.copyWith(busy: true, log: ''));
    try {
      // Mismo motivo que al exportar: mergear contra un catálogo a medio
      // cargar crea duplicados de lo que todavía no llegó.
      await awaitCatalogsReady();
      final summary = await mergeCatalogJson(review.contents.catalog);
      final docs = await _writeKnowledgeDocs(review.contents);
      updateState(
        BundleState(
          log: [
            summary,
            if (docs.isNotEmpty) docs,
            if (review.contents.manifest.requiredSecrets.isNotEmpty)
              'Falta que crees estos secrets para que funcione: '
                  '${review.contents.manifest.requiredSecrets.join(', ')}.',
          ].join('\n'),
        ),
      );
    } catch (error) {
      Log.e('Bundle install failed', error: error);
      updateState(
        data.copyWith(busy: false, log: 'La instalación falló: $error'),
      );
    }
  }

  /// Deja los documentos de saber en la carpeta que la base tenga de este
  /// lado. Una base recién creada por el merge llega sin carpeta —las rutas
  /// no viajan—, y entonces los documentos esperan: se dice cuáles, y la
  /// base los recibe cuando le señales dónde vive.
  Future<String> _writeKnowledgeDocs(BundleContents contents) async {
    if (contents.knowledgeDocs.isEmpty) return '';
    final bases = KnowledgeService.instance.notifier.data.bases;
    var written = 0;
    final waiting = <String>[];

    for (final entry in contents.knowledgeDocs.entries) {
      final base = bases
          .where((candidate) => candidate.name == entry.key)
          .firstOrNull;
      final root = base?.localPath.trim() ?? '';
      if (base == null ||
          base.source != KnowledgeSource.local ||
          root.isEmpty) {
        waiting.add(entry.key);
        continue;
      }
      for (final doc in entry.value.entries) {
        final file = File('$root/${doc.key}');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(doc.value);
        written++;
      }
    }

    return [
      if (written > 0) 'Escribí $written documentos de saber.',
      if (waiting.isNotEmpty)
        'Estas bases llegaron sin carpeta de este lado, así que sus '
            'documentos no se escribieron: ${waiting.join(', ')}. Abrí Saber '
            'y decile a cada una dónde vive.',
    ].join('\n');
  }
}

mixin BundleService {
  static final ReactiveNotifier<BundleViewModel> instance =
      ReactiveNotifier<BundleViewModel>(() => BundleViewModel());
}
