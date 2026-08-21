library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

part 'src/catalog_files.dart';

class CatalogSyncState {
  final bool busy;
  final String log;
  final DateTime? lastSyncAt;

  const CatalogSyncState({this.busy = false, this.log = '', this.lastSyncAt});

  CatalogSyncState copyWith({bool? busy, String? log, DateTime? lastSyncAt}) {
    return CatalogSyncState(
      busy: busy ?? this.busy,
      log: log ?? this.log,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogSyncState &&
          runtimeType == other.runtimeType &&
          busy == other.busy &&
          log == other.log &&
          lastSyncAt == other.lastSyncAt;

  @override
  int get hashCode => Object.hash(busy, log, lastSyncAt);

  @override
  String toString() =>
      'CatalogSyncState(busy: $busy, lastSyncAt: $lastSyncAt)';
}

/// Exports the whole catalog (skills, rules, tools, workflows, MCPs,
/// profiles, stations) to a git repo as portable JSON — references by NAME,
/// never by id — and imports it back with an idempotent by-name merge.
///
/// Deliberately NOT exported: secrets (never), station working directories,
/// document paths, and tasks/threads (machine-local by nature). Imported
/// stations arrive without a folder and the UI asks for one on open.
class CatalogSyncViewModel extends ViewModel<CatalogSyncState> {
  CatalogSyncViewModel() : super(const CatalogSyncState());

  bool _initialized = false;

  @override
  void init() {
    // Guarded: mounting the settings panel mid-sync re-runs init() via
    // reinitializeWithContext(); wiping `busy` here would let a second
    // concurrent git run loose on the same mirror.
    if (_initialized) return;
    _initialized = true;
    updateSilently(const CatalogSyncState());
  }

  /// Serializes the catalog into the mirror, commits and pushes. Returns a
  /// user/agent-facing summary (also kept in [CatalogSyncState.log]).
  Future<String> exportCatalog() => _guarded(() async {
    final dir = await _ensureMirror();
    final written = await _writeCatalog(dir);
    final stamp = DateTime.now().toIso8601String();

    await _git(['add', '-A'], cwd: dir.path);
    final commit = await _git([
      'commit',
      '-m',
      'catalog export $stamp',
    ], cwd: dir.path);
    if (!commit.ok && !commit.output.contains('nothing to commit')) {
      throw _SyncException('git commit falló: ${commit.output}');
    }
    if (commit.ok) {
      final push = await _git(['push', 'origin', 'HEAD'], cwd: dir.path);
      if (!push.ok) throw _SyncException('git push falló: ${push.output}');
    }
    return commit.ok
        ? 'Exporté $written elementos y los subí al repo.'
        : 'Exporté $written elementos — sin cambios respecto del repo.';
  });

  /// Pulls the repo and merges every entity by name (create-if-missing,
  /// update-in-place). Returns the merge summary.
  Future<String> refreshCatalog() => _guarded(() async {
    final dir = await _ensureMirror();
    final summary = await _readAndMergeCatalog(dir);
    return summary;
  });

  Future<String> _guarded(Future<String> Function() operation) async {
    if (data.busy) return 'Ya hay una sincronización en curso.';
    final repoUrl = SettingsService.instance.notifier.data.catalogRepoUrl;
    if (repoUrl.trim().isEmpty) {
      const message =
          'No hay repo de catálogo configurado — cargá la URL en '
          'Configuración → Sincronización.';
      updateState(data.copyWith(log: message));
      return message;
    }

    updateState(data.copyWith(busy: true, log: 'Sincronizando…'));
    try {
      // The catalogs must be REAL before serializing or merging: reading a
      // list whose persisted load is still in flight would export an empty
      // repo (and the fresh `catalog/` rewrite would push those deletions).
      await Future.wait([
        SkillsService.instance.notifier.ready,
        RulesService.instance.notifier.ready,
        ToolsService.instance.notifier.ready,
        WorkflowsService.instance.notifier.ready,
        McpServersService.instance.notifier.ready,
        AgentProfilesService.instance.notifier.ready,
        StationsService.instance.notifier.ready,
      ]);
      final message = await operation();
      updateState(
        CatalogSyncState(busy: false, log: message, lastSyncAt: DateTime.now()),
      );
      return message;
    } on _SyncException catch (error) {
      updateState(data.copyWith(busy: false, log: error.message));
      return error.message;
    } catch (error) {
      final message = 'Sincronización falló: $error';
      Log.e('Catalog sync failed', error: error);
      updateState(data.copyWith(busy: false, log: message));
      return message;
    }
  }

  /// Clone-or-pull of the configured repo into the app-support mirror.
  Future<Directory> _ensureMirror() async {
    final repoUrl = SettingsService.instance.notifier.data.catalogRepoUrl
        .trim();
    final support = await getApplicationSupportDirectory();
    final mirror = Directory('${support.path}/catalog_sync/repo');

    if (Directory('${mirror.path}/.git').existsSync()) {
      final remote = await _git([
        'remote',
        'set-url',
        'origin',
        repoUrl,
      ], cwd: mirror.path);
      if (!remote.ok) {
        throw _SyncException('git remote falló: ${remote.output}');
      }
      final pull = await _git(['pull', '--ff-only'], cwd: mirror.path);
      if (!pull.ok) throw _SyncException('git pull falló: ${pull.output}');
      return mirror;
    }

    await mirror.parent.create(recursive: true);
    final clone = await _git(['clone', repoUrl, mirror.path]);
    if (!clone.ok) throw _SyncException('git clone falló: ${clone.output}');
    return mirror;
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

class _SyncException implements Exception {
  final String message;
  const _SyncException(this.message);
}

mixin CatalogSyncService {
  static final ReactiveNotifier<CatalogSyncViewModel> instance =
      ReactiveNotifier<CatalogSyncViewModel>(() => CatalogSyncViewModel());
}
