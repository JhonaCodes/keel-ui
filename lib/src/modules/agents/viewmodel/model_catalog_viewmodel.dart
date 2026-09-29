import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/model_catalog_state.dart';

/// The ONE model catalog of the app. Every picker and every turn reads it,
/// so `codex debug models` or the OpenRouter listing runs once per
/// [_lifetime], not once per open form.
class ModelCatalogViewModel extends ViewModel<ModelCatalogState> {
  ModelCatalogViewModel() : super(const ModelCatalogState());

  /// A new model shows up within this long without restarting Keel.
  static const _lifetime = Duration(minutes: 10);

  final RemoteModelCatalog _catalog = RemoteModelCatalog();

  @override
  void init() {}

  /// The models of [provider], from its CLI or API. [force] skips the
  /// cache (the refresh button).
  Future<List<AgentModelOption>> load(
    AgentProvider provider, {
    bool force = false,
  }) async {
    final loadedAt = data.loadedAt[provider];
    final cached = data.options[provider];
    if (!force &&
        cached != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _lifetime) {
      return cached;
    }
    _catalog.clear(provider);
    final options = await _catalog.load(provider);
    updateState(
      data.copyWith(
        options: {...data.options, provider: options},
        loadedAt: {...data.loadedAt, provider: DateTime.now()},
      ),
    );
    return options;
  }

  /// The effort to send for [model]: [effort] when the model accepts it,
  /// otherwise the model's own default. Codex forwards the level verbatim
  /// and the API rejects one the model lacks (`max` on gpt-5.5), so this is
  /// what keeps a stored level from breaking a turn after a model change.
  ///
  /// With no model chosen (codex's own config decides) the level is only
  /// sent if every listed model accepts it; otherwise empty, and codex's
  /// config decides that too.
  Future<String> effortFor(
    AgentProvider provider,
    String model,
    String effort,
  ) async {
    final options = switch (provider) {
      AgentProvider.codex || AgentProvider.openCode => await load(provider),
      AgentProvider.claude ||
      AgentProvider.openRouter ||
      AgentProvider.deepSeek => const <AgentModelOption>[],
    };
    final withLevels = options.where((option) => option.efforts.isNotEmpty);
    if (withLevels.isEmpty) return effort;
    final chosen = withLevels.where((option) => option.alias == model);
    if (chosen.isNotEmpty) {
      final option = chosen.first;
      return option.efforts.contains(effort)
          ? effort
          : option.defaultEffort ?? option.efforts.first;
    }
    return withLevels.every((option) => option.efforts.contains(effort))
        ? effort
        : '';
  }
}

mixin ModelCatalogService {
  static final ReactiveNotifier<ModelCatalogViewModel> instance =
      ReactiveNotifier<ModelCatalogViewModel>(ModelCatalogViewModel.new);
}
