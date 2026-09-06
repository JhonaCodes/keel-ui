part of '../system_vault.dart';

/// A partir de cuántos días sin respaldar el vault pasa a estar en falta.
///
/// Nada respalda solo, así que este número es todo el margen que hay entre
/// "lo tengo guardado" y "lo tenía guardado hace una semana".
const int kVaultStaleDays = 3;

class SystemVaultState {
  final bool busy;
  final String log;

  /// Si hay una carpeta de vault elegida.
  final bool configured;

  /// Cuándo se escribió el zip que hay hoy en el vault, o null si no hay
  /// ninguno. Sale del `mtime` del archivo y no de adentro del zip: adentro
  /// no hay fechas, justamente para que sea determinista.
  final DateTime? lastBackupAt;

  final bool isRepo;
  final bool hasRemote;

  /// Lo que ocupa el `.git` del vault, en KiB. Está a la vista porque este
  /// repo llegó a pesar 25 GB sin que nada lo dijera: un zip por commit, cada
  /// quince minutos.
  final int gitSizeKiB;

  /// Si el respaldo commiteado todavía no salió de esta máquina.
  final bool hasUnpushedBackup;

  /// Qué trae el respaldo inspeccionado y qué pisaría. Null hasta que se
  /// mira uno.
  final BackupPreview? preview;

  /// La primera línea de lo último que falló, o vacío si lo último salió
  /// bien.
  ///
  /// Existe porque un respaldo que revienta es INVISIBLE de otra forma: el
  /// zip viejo sigue en el disco con su fecha, así que `lastBackupAt` dice
  /// que hay respaldo y la escalera de abajo pasa de largo — la pantalla
  /// diría que todo está bien sobre un respaldo que nunca se escribió.
  final String lastFailure;

  const SystemVaultState({
    this.busy = false,
    this.log = '',
    this.configured = false,
    this.lastBackupAt,
    this.isRepo = false,
    this.hasRemote = false,
    this.gitSizeKiB = 0,
    this.hasUnpushedBackup = false,
    this.preview,
    this.lastFailure = '',
  });

  /// Qué le falta al respaldo para estar realmente a salvo, o null si no le
  /// falta nada.
  ///
  /// Es una escalera y se contesta el primer peldaño que falla: no sirve
  /// avisar "no está subido" a alguien que ni siquiera tiene remoto. Nada de
  /// esto corre solo —si no apretás el botón no hay respaldo—, así que este
  /// aviso es lo único que separa "creo que está guardado" de "está
  /// guardado".
  ///
  /// [now] entra por parámetro porque el último peldaño mide antigüedad, y un
  /// `DateTime.now()` adentro haría que ese caso no se pueda probar.
  String? warningAt(DateTime now) {
    if (!configured) {
      return 'No elegiste carpeta de vault: nada de esto está respaldado.';
    }
    // Primero que todo: si lo último reventó, cualquier otro peldaño estaría
    // hablando de un respaldo que no se escribió.
    if (lastFailure.isNotEmpty) {
      return 'La última operación del vault falló: $lastFailure';
    }
    final at = lastBackupAt;
    if (at == null) {
      return 'Todavía no hay ningún respaldo en el vault.';
    }
    if (!isRepo) {
      return 'El vault no es un repo git todavía: el respaldo existe, pero '
          'no sale de esta máquina.';
    }
    if (!hasRemote) {
      return 'El vault no tiene remoto configurado: el respaldo no sale de '
          'esta máquina.';
    }
    if (hasUnpushedBackup) {
      return 'El respaldo commiteado todavía no está subido al remoto.';
    }
    // El último peldaño existe porque el respaldo dejó de correr solo: sin
    // esto, un vault impecable con un zip de la semana pasada se ve idéntico
    // a uno al día, y el punto del riel se queda verde para siempre.
    final days = now.difference(at).inDays;
    if (days >= kVaultStaleDays) {
      return 'El último respaldo es de hace $days días: subí uno nuevo.';
    }
    return null;
  }

  /// El aviso contra el reloj de esta máquina. Lo usa la UI; los tests usan
  /// [warningAt], que es determinista.
  String? get warning => warningAt(DateTime.now());

  bool needsAttentionAt(DateTime now) => warningAt(now) != null;

  bool get needsAttention => warning != null;

  SystemVaultState copyWith({
    bool? busy,
    String? log,
    bool? configured,
    DateTime? lastBackupAt,
    bool? isRepo,
    bool? hasRemote,
    int? gitSizeKiB,
    bool? hasUnpushedBackup,
    BackupPreview? preview,
    String? lastFailure,
    bool clearPreview = false,
    bool clearLastBackup = false,
    bool clearFailure = false,
  }) {
    return SystemVaultState(
      busy: busy ?? this.busy,
      log: log ?? this.log,
      configured: configured ?? this.configured,
      lastBackupAt: clearLastBackup
          ? null
          : (lastBackupAt ?? this.lastBackupAt),
      isRepo: isRepo ?? this.isRepo,
      hasRemote: hasRemote ?? this.hasRemote,
      gitSizeKiB: gitSizeKiB ?? this.gitSizeKiB,
      hasUnpushedBackup: hasUnpushedBackup ?? this.hasUnpushedBackup,
      preview: clearPreview ? null : (preview ?? this.preview),
      lastFailure: clearFailure ? '' : (lastFailure ?? this.lastFailure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemVaultState &&
          runtimeType == other.runtimeType &&
          busy == other.busy &&
          log == other.log &&
          configured == other.configured &&
          lastBackupAt == other.lastBackupAt &&
          isRepo == other.isRepo &&
          hasRemote == other.hasRemote &&
          gitSizeKiB == other.gitSizeKiB &&
          hasUnpushedBackup == other.hasUnpushedBackup &&
          preview == other.preview;

  @override
  int get hashCode => Object.hash(
    busy,
    log,
    configured,
    lastBackupAt,
    isRepo,
    hasRemote,
    gitSizeKiB,
    hasUnpushedBackup,
    preview,
  );

  @override
  String toString() =>
      'SystemVaultState(busy: $busy, lastBackupAt: $lastBackupAt, '
      'unpushed: $hasUnpushedBackup)';
}

/// Respaldar y restaurar el sistema entero contra la carpeta del vault.
///
/// La forma de lo que viaja no se decide acá: viene de `catalog_shape`
/// ([catalogAsJson] / [mergeCatalogJson]), igual que el respaldo en un
/// archivo suelto. Lo propio de este camino es el destino —un zip
/// determinista en una carpeta versionada con git— y las dos cosas que el
/// catálogo portable no incluye: los ajustes y qué secrets existen.
class SystemVaultViewModel extends ViewModel<SystemVaultState> {
  SystemVaultViewModel() : super(const SystemVaultState());

  /// El respaldo ya inspeccionado, entero, para aplicarlo sin releerlo.
  VaultContents? _loaded;

  bool _initialized = false;

  @override
  void init() {
    // Guardado: montar el panel de configuración a mitad de un respaldo
    // re-dispara init() por `reinitializeWithContext()`, y limpiar `busy`
    // acá dejaría suelto un segundo git sobre el mismo vault.
    if (_initialized) return;
    _initialized = true;
    updateSilently(const SystemVaultState());
    unawaited(refreshStatus());
  }

  /// La carpeta del vault, o null si el usuario todavía no eligió ninguna.
  String? get _vaultDirectory {
    final path = SettingsService.instance.notifier.data.vaultPath.trim();
    return path.isEmpty ? null : path;
  }

  File? get _backupFile {
    final dir = _vaultDirectory;
    return dir == null ? null : File('$dir/$kVaultBackupFileName');
  }

  /// Relee del disco cuándo fue el último respaldo y en qué estado está el
  /// repo. Barato y sin efectos: se llama al arrancar y después de cada
  /// operación.
  Future<void> refreshStatus() async {
    // Al arrancar esto corre antes que la carga de ajustes: sin esperarla,
    // la carpeta del vault se lee vacía y el panel diría "nunca respaldaste"
    // teniendo un respaldo al lado.
    await SettingsService.instance.notifier.ready;
    final dir = _vaultDirectory;
    final file = _backupFile;
    final exists = file != null && file.existsSync();
    final status = dir == null
        ? const (
            isRepo: false,
            hasRemote: false,
            hasUnpushedBackup: false,
            gitSizeKiB: 0,
          )
        : await vaultRepoStatus(dir);

    updateState(
      data.copyWith(
        configured: dir != null,
        lastBackupAt: exists ? file.lastModifiedSync() : null,
        clearLastBackup: !exists,
        isRepo: status.isRepo,
        hasRemote: status.hasRemote,
        gitSizeKiB: status.gitSizeKiB,
        hasUnpushedBackup: status.hasUnpushedBackup,
      ),
    );
  }

  // ── respaldar ───────────────────────────────────────────────────────

  /// Escribe `keel-backup.zip` en el vault, lo commitea y lo sube al remoto.
  /// Devuelve el resumen (también queda en [SystemVaultState.log]).
  ///
  /// Es UN solo camino a propósito. Antes había dos —"Respaldar" escribía el
  /// zip y "Respaldar y subir" además lo publicaba—, y un respaldo que se
  /// queda en este disco no es un respaldo contra perder este disco: la
  /// mitad barata se veía igual de terminada que la que sirve.
  ///
  /// **No atenúa la app.** Respaldar no pisa nada de lo que estés haciendo:
  /// junta una foto de lo que ya está en memoria y escribe un archivo. Se
  /// avisa —la franja de arriba y el icono del riel—, no se bloquea. Lo que
  /// sí bloquea es RESTAURAR, que reemplaza el sistema abajo tuyo.
  Future<String> backup() => AppStatusService.instance.notifier.inBackground(
    'Respaldando el sistema',
    _backup,
  );

  Future<String> _backup() => _guarded(() async {
    final dir = _vaultDirectory;
    if (dir == null) {
      throw const _VaultException(
        'No hay carpeta de vault elegida — cargala en Configuración → '
        'Respaldo del sistema.',
      );
    }
    if (!Directory(dir).existsSync()) {
      throw _VaultException('La carpeta del vault no existe: $dir');
    }

    // A OTRO isolate. Recorrer las carpetas de saber, leer cada archivo y
    // comprimir es medio segundo con pocas bases y varios con muchas; acá
    // adentro eso era un freeze de la app entera en cada respaldo.
    final job = _jobFor(dir);
    final written = await runOffThread(writeVaultArchive, job);

    final parts = [
      'Respaldé ${written.catalogCount} elementos, '
          '${written.secretCount} secrets por nombre'
          '${written.documentCount == 0 ? '' : ' y ${written.documentCount} documentos'}'
          ' (${(written.byteLength / 1024).round()} KB).',
      if (written.skipped.isNotEmpty)
        'Afuera por tamaño (más de ${kMaxVaultDocBytes ~/ (1024 * 1024)} MB): '
            '${written.skipped.join(', ')}.',
    ];

    final remote = SettingsService.instance.notifier.data.vaultRepoUrl.trim();
    if (remote.isEmpty) {
      throw const _VaultException(
        'Escribí el respaldo, pero no hay repo del vault configurado: '
        'cargá la URL en Configuración → Respaldo del sistema y volvé a '
        'subirlo.',
      );
    }

    await ensureVaultRepo(dir, remote);
    parts.add(
      await commitVault(
        dir,
        message: 'respaldo ${DateTime.now().toIso8601String()}',
        push: true,
      ),
    );
    return parts.join('\n');
  });

  /// El encargo que se manda al otro isolate.
  ///
  /// Todo lo que hay acá se lee de memoria y es barato. Lo que cuesta —abrir
  /// carpetas, leer bytes, comprimir— queda del otro lado.
  VaultJob _jobFor(String dir) {
    return VaultJob(
      destinationPath: '$dir/$kVaultBackupFileName',
      catalog: catalogAsJson(),
      settings: vaultSettingsOf(SettingsService.instance.notifier.data),
      secrets: [
        // Los VALORES no viajan: el vault va a un remoto y lo que entra en
        // la historia de git no sale más. Del otro lado quedan pendientes.
        for (final secret in SecretsService.instance.notifier.data.secrets)
          {'name': secret.name, 'description': secret.description},
      ],
      knowledgeRoots: {
        for (final base in KnowledgeService.instance.notifier.data.bases)
          // Una base git se recupera clonando, y una que vive DENTRO del
          // vault ya está en el repo en claro: meterla al zip la duplicaría
          // y haría que el binario cambie cada vez que se edita un markdown.
          if (base.source == KnowledgeSource.local &&
              vaultRelativeOf(base.localPath) == null)
            base.name: base.localPath,
      },
    );
  }

  // ── restaurar ───────────────────────────────────────────────────────

  /// Lee el zip del vault y arma el preview: qué trae y qué pisaría. No
  /// aplica nada — eso es [applyLoaded], después de que el usuario elija.
  Future<String> inspectVault() => _guarded(() async {
    final file = _backupFile;
    if (file == null) {
      throw const _VaultException(
        'No hay carpeta de vault elegida — cargala en Configuración.',
      );
    }
    if (!file.existsSync()) {
      throw _VaultException(
        'No hay ningún $kVaultBackupFileName en el vault. Si venís de otra '
        'máquina, cloná el repo primero.',
      );
    }
    return _inspectFile(file);
  });

  /// Clona [url] en [destination], lo adopta como vault y lo inspecciona.
  /// Es el camino de una instalación nueva: traer el repo y mirar qué trae,
  /// todo antes de tocar nada del sistema.
  Future<String> cloneAndInspect({
    required String url,
    required String destination,
  }) => _guarded(() async {
    if (url.trim().isEmpty || destination.trim().isEmpty) {
      throw const _VaultException(
        'Faltan la URL del repo y la carpeta destino.',
      );
    }
    await cloneVaultRepo(url.trim(), destination.trim());

    final settings = SettingsService.instance.notifier;
    settings.setVaultPath(destination.trim());
    settings.setVaultRepoUrl(url.trim());

    final file = File('${destination.trim()}/$kVaultBackupFileName');
    if (!file.existsSync()) {
      return 'Cloné el repo y lo adopté como vault, pero no trae ningún '
          '$kVaultBackupFileName: no hay nada que restaurar.';
    }
    return _inspectFile(file);
  });

  Future<String> _inspectFile(File file) async {
    final contents = decodeVault(await file.readAsBytes());
    _loaded = contents;
    updateState(
      data.copyWith(
        preview: backupPreviewOf(
          contents.catalog,
          knowledgeDocCounts: {
            for (final entry in contents.knowledgeDocs.entries)
              entry.key: entry.value.length,
          },
          secretCount: contents.secrets.length,
        ),
      ),
    );
    return 'Respaldo leído: ${contents.catalogCount} elementos.';
  }

  /// Aplica el respaldo ya inspeccionado: solo las [sections] elegidas.
  Future<String> applyLoaded({required Set<BackupSection> sections}) =>
      AppStatusService.instance.notifier.during(
        'Restaurando el respaldo',
        () => _applyLoaded(sections),
      );

  Future<String> _applyLoaded(Set<BackupSection> sections) =>
      _guarded(() async {
        final loaded = _loaded;
        if (loaded == null) {
          throw const _VaultException('No hay ningún respaldo leído.');
        }
        return _apply(loaded, sections);
      });

  /// El trabajo de aplicar, sin el guardado: lo comparten el panel de
  /// restaurar —que deja elegir secciones— y la bienvenida, que las aplica
  /// todas porque el sistema está vacío y no hay nada que elegir.
  ///
  /// Los ajustes y los secrets van siempre: no pisan nada (un secret que ya
  /// existe se deja intacto) y son justo lo que falta en una instalación
  /// nueva.
  Future<String> _apply(
    VaultContents loaded,
    Set<BackupSection> sections,
  ) async {
    final byCategory = {
      for (final section in sections)
        if (loaded.catalog[section.category] != null)
          section.category: loaded.catalog[section.category]!,
    };

    final parts = <String>[];
    if (byCategory.isNotEmpty) parts.add(await mergeCatalogJson(byCategory));
    if (sections.contains(BackupSection.knowledgeBases)) {
      final docs = await _applyKnowledgeDocs(loaded);
      if (docs.isNotEmpty) parts.add(docs);
    }
    if (loaded.settings.isNotEmpty) {
      SettingsService.instance.notifier.applyRestored(
        AppSettings.fromJson(loaded.settings),
      );
      parts.add('Restauré los ajustes.');
    }
    parts.add(_applySecrets(loaded));

    return parts.join('\n');
  }

  /// El arranque de una instalación limpia, entero y de una: adopta el
  /// vault, lo trae si hace falta, y restaura TODO sin preguntar.
  ///
  /// No pregunta porque no hay nada que perder — esto solo se ofrece con el
  /// sistema vacío ([catalogIsEmpty]). Si la carpeta ya tiene el respaldo
  /// (porque clonaste el repo a mano antes de abrir la app), no clona nada:
  /// la adopta como está.
  Future<String> bootstrapFrom({
    required String url,
    required String destination,
  }) => AppStatusService.instance.notifier.during(
    'Trayendo el vault',
    () => _bootstrapFrom(url, destination),
  );

  Future<String> _bootstrapFrom(
    String url,
    String destination,
  ) => _guarded(() async {
    final dir = destination.trim();
    if (dir.isEmpty) {
      throw const _VaultException('Elegí en qué carpeta va a vivir el vault.');
    }

    final alreadyThere = File('$dir/$kVaultBackupFileName').existsSync();
    if (!alreadyThere) {
      if (url.trim().isEmpty) {
        throw _VaultException(
          'Esa carpeta no tiene ningún $kVaultBackupFileName y no diste una '
          'URL para clonar.',
        );
      }
      await cloneVaultRepo(url.trim(), dir);
    }

    final settings = SettingsService.instance.notifier;
    settings.setVaultPath(dir);
    if (url.trim().isNotEmpty) settings.setVaultRepoUrl(url.trim());

    final file = File('$dir/$kVaultBackupFileName');
    if (!file.existsSync()) {
      throw _VaultException(
        'Traje el repo, pero no incluye ningún $kVaultBackupFileName: no hay '
        'nada que restaurar.',
      );
    }

    await _inspectFile(file);
    final summary = await _apply(_loaded!, BackupSection.values.toSet());
    settings.markVaultOnboardingDone();
    return summary;
  });

  /// Escribe los documentos del zip en las bases que tengan carpeta en ESTA
  /// máquina. Las bases que viven en el vault no pasan por acá: sus archivos
  /// ya llegaron con el clone, solo hay que reindexarlas.
  Future<String> _applyKnowledgeDocs(VaultContents loaded) async {
    final knowledge = KnowledgeService.instance.notifier;
    var written = 0;
    final notes = <String>[];

    for (final entry in loaded.knowledgeDocs.entries) {
      final base = knowledge.data.bases
          .where((base) => base.name == entry.key)
          .firstOrNull;
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
      final root = base.localPath.trim();
      if (root.isEmpty) {
        notes.add(
          'la base "${entry.key}" no tiene carpeta en esta máquina: '
          'asignale una y volvé a restaurar',
        );
        continue;
      }

      for (final doc in entry.value.entries) {
        // Una relativa que sube de nivel escribiría fuera de la base.
        if (doc.key.split('/').contains('..')) continue;
        final file = File('$root/${doc.key}');
        await file.create(recursive: true);
        await file.writeAsBytes(doc.value);
        written++;
      }
      unawaited(knowledge.reindexBase(base.id));
    }

    // Las bases que viven en el vault no traen documentos en el zip, pero su
    // índice sí hay que rehacerlo: los archivos son nuevos en esta máquina.
    for (final base in knowledge.data.bases) {
      if (base.source != KnowledgeSource.local) continue;
      if (vaultRelativeOf(base.localPath) == null) continue;
      unawaited(knowledge.reindexBase(base.id));
    }

    return [
      if (written > 0) 'Escribí $written documentos de saber.',
      if (notes.isNotEmpty) 'Saber sin aplicar: ${notes.join('; ')}.',
    ].join('\n');
  }

  /// Crea los secrets que falten, siempre SIN valor. Uno que ya existe acá
  /// no se toca: el respaldo no trae valores, así que no hay nada que pueda
  /// aportarle.
  String _applySecrets(VaultContents loaded) {
    if (loaded.secrets.isEmpty) return 'El respaldo no registra secrets.';

    final secrets = SecretsService.instance.notifier;
    var created = 0;
    for (final raw in loaded.secrets) {
      final name = raw['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final exists = secrets.data.secrets.any((secret) => secret.name == name);
      if (exists) continue;
      final error = secrets.createSecret(
        name: name,
        description: raw['description'] as String? ?? '',
        value: '',
      );
      if (error == null) created++;
    }

    final pending = secrets.data.secrets.where((secret) => secret.isPending);
    return [
      'Secrets: $created creados sin valor.',
      if (pending.isNotEmpty)
        'Faltan completar: ${pending.map((secret) => secret.name).join(', ')}.',
    ].join(' ');
  }

  // ── plomería ────────────────────────────────────────────────────────

  /// Deja anotado que falló, para que el aviso lo diga sin que nadie tenga
  /// que abrir el panel.
  ///
  /// Al aviso va solo la PRIMERA línea: un error de isolate son doscientas
  /// líneas de `<- _child in Instance of ...` y eso no entra en una franja.
  /// El texto entero queda en [SystemVaultState.log], que es donde se mira.
  String _failed(String message) {
    final headline = message.split('\n').first.trim();
    updateState(
      data.copyWith(
        busy: false,
        log: message,
        lastFailure: headline.length > 160
            ? '${headline.substring(0, 157)}…'
            : headline,
      ),
    );
    return message;
  }

  Future<String> _guarded(Future<String> Function() operation) async {
    if (data.busy) return 'Ya hay una operación del vault en curso.';
    updateState(data.copyWith(busy: true, log: ''));
    try {
      // Los catálogos tienen que estar REALES antes de serializar o
      // mergear: leer una lista cuya carga sigue en vuelo respaldaría un
      // sistema vacío y lo escribiría encima del bueno.
      await awaitCatalogsReady();
      final message = await operation();
      updateState(data.copyWith(busy: false, log: message, clearFailure: true));
      await refreshStatus();
      return message;
    } on _VaultException catch (error) {
      return _failed(error.message);
    } on VaultFormatException catch (error) {
      return _failed(error.message);
    } catch (error) {
      Log.e('System vault operation failed', error: error);
      return _failed('El vault falló: $error');
    }
  }
}

/// Los ajustes que viajan en un respaldo.
///
/// La carpeta del vault y el tamaño de ventana quedan afuera por ser de esta
/// máquina: restaurar no tiene por qué mover la ventana ni redirigir el
/// vault a una ruta que del otro lado no existe.
Map<String, dynamic> vaultSettingsOf(AppSettings settings) => {
  'chatFontScale': settings.chatFontScale,
  'extraAllowedTools': settings.extraAllowedTools,
  'knowledgeRepoUrl': settings.knowledgeRepoUrl,
  'vaultRepoUrl': settings.vaultRepoUrl,
};

mixin SystemVaultService {
  static final ReactiveNotifier<SystemVaultViewModel> instance =
      ReactiveNotifier<SystemVaultViewModel>(() => SystemVaultViewModel());
}
