import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_core/modules/knowledge/model/knowledge_state.dart';
import 'package:keel_core/modules/knowledge/service/knowledge_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

export 'package:keel_core/modules/knowledge/model/knowledge_state.dart';

/// Thin mirror over [KnowledgeStore] (keel_core): the real catalog,
/// indexing, sync and agent-brief logic lives there so a future headless
/// CLI can run it without Flutter.
class KnowledgeViewModel extends StoreMirrorViewModel<KnowledgeState> {
  KnowledgeViewModel() : super(KnowledgeStore.instance);

  Future<void> get ready => KnowledgeStore.instance.ready;
  Future<void> get indexReady => KnowledgeStore.instance.indexReady;

  // ── catálogo ────────────────────────────────────────────────────────

  String? createBase({
    required String name,
    required String description,
    required KnowledgeSource source,
    String gitUrl = '',
    String gitBranch = '',
    String localPath = '',
    bool createFolderIfMissing = false,
  }) => KnowledgeStore.instance.createBase(
    name: name,
    description: description,
    source: source,
    gitUrl: gitUrl,
    gitBranch: gitBranch,
    localPath: localPath,
    createFolderIfMissing: createFolderIfMissing,
  );

  String? updateBase(
    String id, {
    required String name,
    required String description,
    required KnowledgeSource source,
    String gitUrl = '',
    String gitBranch = '',
    String localPath = '',
  }) => KnowledgeStore.instance.updateBase(
    id,
    name: name,
    description: description,
    source: source,
    gitUrl: gitUrl,
    gitBranch: gitBranch,
    localPath: localPath,
  );

  void deleteBase(String id) => KnowledgeStore.instance.deleteBase(id);

  String? setBaseFolder(String id, String path) =>
      KnowledgeStore.instance.setBaseFolder(id, path);

  // ── lecturas ────────────────────────────────────────────────────────

  KnowledgeBase? baseById(String id) => KnowledgeStore.instance.baseById(id);

  KnowledgeBase? baseByName(String name) =>
      KnowledgeStore.instance.baseByName(name);

  String rootPathOf(KnowledgeBase base) =>
      KnowledgeStore.instance.rootPathOf(base);

  KnowledgeIndex? indexOf(String baseId) =>
      KnowledgeStore.instance.indexOf(baseId);

  // ── índice ──────────────────────────────────────────────────────────

  Future<void> reindexBase(String id) =>
      KnowledgeStore.instance.reindexBase(id);

  // ── sincronización ──────────────────────────────────────────────────

  Future<String> syncBase(String id) => KnowledgeStore.instance.syncBase(id);

  Future<String> syncAll() => KnowledgeStore.instance.syncAll();

  // ── documento abierto ───────────────────────────────────────────────

  Future<void> selectDocument(String baseId, String relativePath) =>
      KnowledgeStore.instance.selectDocument(baseId, relativePath);

  void clearSelection() => KnowledgeStore.instance.clearSelection();

  Future<void> openWithSystem(String absolutePath) =>
      KnowledgeStore.instance.openWithSystem(absolutePath);

  // ── lo que ve un agente ─────────────────────────────────────────────

  String briefFor(List<String> baseNames) =>
      KnowledgeStore.instance.briefFor(baseNames);
}

mixin KnowledgeService {
  static final ReactiveNotifier<KnowledgeViewModel> instance =
      ReactiveNotifier<KnowledgeViewModel>(() => KnowledgeViewModel());
}
