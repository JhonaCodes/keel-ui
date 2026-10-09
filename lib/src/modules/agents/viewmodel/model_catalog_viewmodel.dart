import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/model_catalog_state.dart';
import 'package:keel_core/modules/agents/service/model_catalog_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

/// Thin mirror over [ModelCatalogStore] (keel_core): the real catalog logic
/// lives there so keel-server can run it without Flutter.
class ModelCatalogViewModel extends StoreMirrorViewModel<ModelCatalogState> {
  ModelCatalogViewModel() : super(ModelCatalogStore.instance);

  Future<List<AgentModelOption>> load(
    AgentProvider provider, {
    bool force = false,
  }) => ModelCatalogStore.instance.load(provider, force: force);

  /// The providers a picker offers: one that can't run here is left out,
  /// unless it is [keep], the value the picker starts at.
  List<AgentProvider> providers({AgentProvider? keep}) =>
      ModelCatalogStore.instance.providers(keep: keep);

  Future<String> effortFor(
    AgentProvider provider,
    String model,
    String effort,
  ) => ModelCatalogStore.instance.effortFor(provider, model, effort);
}

mixin ModelCatalogService {
  static final ReactiveNotifier<ModelCatalogViewModel> instance =
      ReactiveNotifier<ModelCatalogViewModel>(ModelCatalogViewModel.new);
}
