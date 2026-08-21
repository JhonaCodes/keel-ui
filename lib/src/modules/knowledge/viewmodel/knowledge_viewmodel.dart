import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';

class KnowledgeState {
  final bool busy;
  final String status;

  /// Repo-relative paths of every markdown doc, sorted.
  final List<String> documents;
  final String? selectedPath;
  final String selectedContent;

  const KnowledgeState({
    this.busy = false,
    this.status = '',
    this.documents = const [],
    this.selectedPath,
    this.selectedContent = '',
  });

  KnowledgeState copyWith({
    bool? busy,
    String? status,
    List<String>? documents,
    String? selectedPath,
    String? selectedContent,
  }) {
    return KnowledgeState(
      busy: busy ?? this.busy,
      status: status ?? this.status,
      documents: documents ?? this.documents,
      selectedPath: selectedPath ?? this.selectedPath,
      selectedContent: selectedContent ?? this.selectedContent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeState &&
          runtimeType == other.runtimeType &&
          busy == other.busy &&
          status == other.status &&
          listEquals(documents, other.documents) &&
          selectedPath == other.selectedPath &&
          selectedContent == other.selectedContent;

  @override
  int get hashCode => Object.hash(
    busy,
    status,
    Object.hashAll(documents),
    selectedPath,
    selectedContent,
  );

  @override
  String toString() =>
      'KnowledgeState(busy: $busy, documents: ${documents.length}, '
      'selected: $selectedPath)';
}

/// The Knowledge section: a git repo of markdown docs, configured by URL in
/// Settings, cloned/pulled into app support and browsed in-app. Agents can
/// read it too — [mirrorPathIfPresent] is advertised in Keel AI's seed.
class KnowledgeViewModel extends ViewModel<KnowledgeState> {
  KnowledgeViewModel() : super(const KnowledgeState());

  /// First-init guard (same reasoning as the catalog VMs): the first access
  /// can come from an MCP tool with no widget mounted, and the later
  /// builder-triggered re-init must not wipe documents or the busy flag of
  /// an in-flight update.
  Future<void>? _ready;

  @override
  void init() {
    if (_ready != null) return;
    updateSilently(const KnowledgeState());
    _ready = _loadLocalIndex();
  }

  static Future<String> mirrorPath() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}/knowledge/repo';
  }

  /// The local docs path IF an update already ran on this machine.
  static String? mirrorPathIfPresentSync;

  Future<void> _loadLocalIndex() async {
    final path = await mirrorPath();
    if (!Directory('$path/.git').existsSync()) {
      updateState(
        data.copyWith(
          status:
              'Sin documentación descargada todavía — configurá el repo en '
              'Configuración y tocá Actualizar.',
        ),
      );
      return;
    }
    mirrorPathIfPresentSync = path;
    updateState(
      data.copyWith(documents: _indexMarkdown(path), status: ''),
    );
  }

  /// Clone-or-pull of the configured docs repo, then reindex.
  Future<String> update() async {
    if (data.busy) return 'Ya hay una actualización en curso.';
    final repoUrl = SettingsService.instance.notifier.data.knowledgeRepoUrl
        .trim();
    if (repoUrl.isEmpty) {
      const message =
          'No hay repo de conocimiento configurado — cargá la URL en '
          'Configuración → Conocimiento.';
      updateState(data.copyWith(status: message));
      return message;
    }

    updateState(data.copyWith(busy: true, status: 'Actualizando…'));
    try {
      final path = await mirrorPath();
      final hasClone = Directory('$path/.git').existsSync();
      final result = hasClone
          ? await _git(['pull', '--ff-only'], cwd: path)
          : await () async {
              await Directory(path).parent.create(recursive: true);
              return _git(['clone', '--depth', '1', repoUrl, path]);
            }();
      if (!result.ok) {
        final message = 'Actualización falló: ${result.output}';
        updateState(data.copyWith(busy: false, status: message));
        return message;
      }
      if (hasClone) {
        final remote = await _git([
          'remote',
          'set-url',
          'origin',
          repoUrl,
        ], cwd: path);
        if (!remote.ok) Log.w('knowledge remote set-url: ${remote.output}');
      }
      mirrorPathIfPresentSync = path;
      final documents = _indexMarkdown(path);
      final message = 'Documentación al día: ${documents.length} documentos.';
      updateState(
        data.copyWith(busy: false, status: message, documents: documents),
      );
      return message;
    } catch (error) {
      final message = 'Actualización falló: $error';
      Log.e('Knowledge update failed', error: error);
      updateState(data.copyWith(busy: false, status: message));
      return message;
    }
  }

  Future<void> select(String relativePath) async {
    final root = await mirrorPath();
    try {
      final content = await File('$root/$relativePath').readAsString();
      updateState(
        data.copyWith(selectedPath: relativePath, selectedContent: content),
      );
    } catch (error) {
      updateState(
        data.copyWith(
          selectedPath: relativePath,
          selectedContent: 'No pude leer el documento: $error',
        ),
      );
    }
  }

  List<String> _indexMarkdown(String root) {
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) return const [];
    final docs = <String>[];
    for (final entity in rootDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final relative = entity.path.substring(root.length + 1);
      if (relative.startsWith('.git/')) continue;
      docs.add(relative);
    }
    docs.sort();
    return docs;
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
}

mixin KnowledgeService {
  static final ReactiveNotifier<KnowledgeViewModel> instance =
      ReactiveNotifier<KnowledgeViewModel>(() => KnowledgeViewModel());
}
