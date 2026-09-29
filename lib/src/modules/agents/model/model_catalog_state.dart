import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// The model lists already loaded, per provider, and when. Transient: it is
/// rebuilt from the CLIs and APIs on every run, so it is never serialized.
class ModelCatalogState {
  const ModelCatalogState({
    this.options = const {},
    this.loadedAt = const {},
  });

  final Map<AgentProvider, List<AgentModelOption>> options;
  final Map<AgentProvider, DateTime> loadedAt;

  ModelCatalogState copyWith({
    Map<AgentProvider, List<AgentModelOption>>? options,
    Map<AgentProvider, DateTime>? loadedAt,
  }) => ModelCatalogState(
    options: options ?? this.options,
    loadedAt: loadedAt ?? this.loadedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelCatalogState &&
          _sameOptions(options, other.options) &&
          loadedAt.length == other.loadedAt.length &&
          loadedAt.entries.every(
            (entry) => other.loadedAt[entry.key] == entry.value,
          );

  static bool _sameOptions(
    Map<AgentProvider, List<AgentModelOption>> a,
    Map<AgentProvider, List<AgentModelOption>> b,
  ) =>
      a.length == b.length &&
      a.entries.every((entry) {
        final other = b[entry.key];
        return other != null &&
            other.length == entry.value.length &&
            entry.value.indexed.every((item) => other[item.$1] == item.$2);
      });

  @override
  int get hashCode => Object.hash(
    Object.hashAll(
      options.entries.map(
        (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
      ),
    ),
    Object.hashAll(
      loadedAt.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}
