import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// A model the user can pick for an agent. [alias] is what the provider's
/// CLI receives verbatim; [label] is what the UI shows.
class AgentModelOption {
  final String alias;
  final String label;

  const AgentModelOption({required this.alias, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentModelOption &&
          runtimeType == other.runtimeType &&
          alias == other.alias &&
          label == other.label;

  @override
  int get hashCode => Object.hash(alias, label);

  @override
  String toString() => 'AgentModelOption(alias: $alias, label: $label)';
}

const kDefaultClaudeModelAlias = 'sonnet';

const kClaudeModelOptions = <AgentModelOption>[
  AgentModelOption(alias: 'sonnet', label: 'Sonnet 5'),
  AgentModelOption(alias: 'opus', label: 'Opus 5'),
  AgentModelOption(alias: 'fable', label: 'Fable 5'),
  AgentModelOption(alias: 'claude-haiku-4-5-20251001', label: 'Haiku 4.5'),
];

/// Empty alias = don't pass `-m` at all, so codex resolves the model from
/// the user's own `~/.codex/config.toml`. It leads the list because the
/// codex lineup moves faster than this file and an account may not have
/// every slug enabled — "whatever codex would use" never goes stale.
const kCodexDefaultModelAlias = '';

/// API providers keep a concrete default so a new agent is immediately
/// runnable. Their remote catalog can replace this selection at any time.
const kDefaultOpenRouterModelAlias = 'openrouter/auto';
const kDefaultDeepSeekModelAlias = 'deepseek-v4-pro';

/// Taken from codex's own catalog (`~/.codex/models_cache.json`), keeping
/// only the entries it marks `visibility: list` — the same ones its picker
/// offers. `gpt-reserve` and `codex-auto-review` are marked `hide` there and
/// are deliberately not offered here.
const kCodexModelOptions = <AgentModelOption>[
  AgentModelOption(
    alias: kCodexDefaultModelAlias,
    label: 'El de tu config de codex',
  ),
  AgentModelOption(alias: 'gpt-5.5', label: 'GPT-5.5'),
  AgentModelOption(alias: 'gpt-5.4', label: 'GPT-5.4'),
  AgentModelOption(alias: 'gpt-5.4-mini', label: 'GPT-5.4-Mini'),
];

const kOpenRouterModelOptions = <AgentModelOption>[
  AgentModelOption(alias: kDefaultOpenRouterModelAlias, label: 'Auto'),
];

const kDeepSeekModelOptions = <AgentModelOption>[
  AgentModelOption(alias: 'deepseek-v4-pro', label: 'DeepSeek V4 Pro'),
  AgentModelOption(alias: 'deepseek-v4-flash', label: 'DeepSeek V4 Flash'),
];

/// The models that belong to [provider] — the two CLIs share nothing here,
/// so offering Claude aliases to a codex agent (as this app did until the
/// catalogs were split) offers a choice its CLI cannot honour.
List<AgentModelOption> modelOptionsFor(AgentProvider provider) {
  return switch (provider) {
    AgentProvider.claude => kClaudeModelOptions,
    AgentProvider.codex => kCodexModelOptions,
    AgentProvider.openRouter => kOpenRouterModelOptions,
    AgentProvider.deepSeek => kDeepSeekModelOptions,
  };
}

String defaultModelFor(AgentProvider provider) {
  return switch (provider) {
    AgentProvider.claude => kDefaultClaudeModelAlias,
    AgentProvider.codex => kCodexDefaultModelAlias,
    AgentProvider.openRouter => kDefaultOpenRouterModelAlias,
    AgentProvider.deepSeek => kDefaultDeepSeekModelAlias,
  };
}

/// Label for [alias] under [provider]. An alias outside the catalog is shown
/// as-is: `register`-style flows and Keel AI may set an exact model id the
/// list doesn't name, and hiding it would be worse than showing the raw id.
String modelLabelFor(AgentProvider provider, String alias) {
  for (final option in modelOptionsFor(provider)) {
    if (option.alias == alias) return option.label;
  }
  return alias.isEmpty ? 'El de tu config de codex' : alias;
}

/// What the model dropdown should START at for an agent whose stored model
/// may predate the split: a codex agent carrying a Claude alias is reset to
/// the codex default, so saving the form heals the record instead of
/// keeping a value its CLI would reject.
String initialModelFor(AgentProvider provider, String storedModel) {
  if (provider == AgentProvider.codex && isClaudeModelAlias(storedModel)) {
    return kCodexDefaultModelAlias;
  }
  return storedModel;
}

bool isClaudeModelAlias(String alias) =>
    kClaudeModelOptions.any((option) => option.alias == alias);

/// The value for codex's `-m`, or null when nothing should be passed.
///
/// Guards the same legacy case at RUN time: agents created before the
/// catalogs were split still carry `sonnet`, and codex would fail on a model
/// name that isn't its own.
String? codexModelArgument(String model) {
  if (model.isEmpty || isClaudeModelAlias(model)) return null;
  return model;
}
