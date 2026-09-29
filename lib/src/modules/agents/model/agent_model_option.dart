import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// A model the user can pick for an agent. [alias] is what the provider's
/// CLI receives verbatim; [label] is what the UI shows.
class AgentModelOption {
  final String alias;
  final String label;

  /// Reasoning levels the model accepts, as its provider lists them. Empty:
  /// unknown, every level is offered.
  final List<String> efforts;

  /// The level the provider uses when none is sent. Null: unknown.
  final String? defaultEffort;

  const AgentModelOption({
    required this.alias,
    required this.label,
    this.efforts = const [],
    this.defaultEffort,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentModelOption &&
          runtimeType == other.runtimeType &&
          alias == other.alias &&
          label == other.label &&
          defaultEffort == other.defaultEffort &&
          efforts.length == other.efforts.length &&
          efforts.indexed.every((entry) => other.efforts[entry.$1] == entry.$2);

  @override
  int get hashCode =>
      Object.hash(alias, label, defaultEffort, Object.hashAll(efforts));

  @override
  String toString() => 'AgentModelOption(alias: $alias, label: $label)';
}

extension AgentModelEfforts on List<AgentModelOption> {
  /// The reasoning levels [model] accepts, or empty when unknown.
  List<String> effortsOf(String model) =>
      where((option) => option.alias == model).firstOrNull?.efforts ??
      const [];
}

const kDefaultClaudeModelAlias = 'sonnet';

/// Family aliases. The Claude CLI resolves each one to the newest model of
/// its family, so what runs never goes stale — only a version number written
/// here would. That is why these labels carry none: `RemoteModelCatalog`
/// relabels them with the version the CLI actually reported.
const kClaudeModelOptions = <AgentModelOption>[
  AgentModelOption(alias: 'sonnet', label: 'Sonnet'),
  AgentModelOption(alias: 'opus', label: 'Opus'),
  AgentModelOption(alias: 'fable', label: 'Fable'),
  AgentModelOption(alias: 'haiku', label: 'Haiku'),
];

/// Empty alias = don't pass `-m` at all, so codex resolves the model from
/// the user's own `~/.codex/config.toml`. It leads the list because the
/// codex lineup moves faster than this file and an account may not have
/// every slug enabled — "whatever codex would use" never goes stale.
const kCodexDefaultModelAlias = '';

const kCodexDefaultModelOption = AgentModelOption(
  alias: kCodexDefaultModelAlias,
  label: 'El de tu config de codex',
);

/// API providers keep a concrete default so a new agent is immediately
/// runnable. Their remote catalog can replace this selection at any time.
const kDefaultOpenRouterModelAlias = 'openrouter/auto';
const kDefaultDeepSeekModelAlias = 'deepseek-v4-pro';

/// What remains when `codex debug models` cannot answer (codex not
/// installed, or failing): only "whatever your codex config uses". Model
/// slugs written here went stale and offered models the CLI rejected; the
/// real list always comes from the CLI (`RemoteModelCatalog`).
const kCodexModelOptions = <AgentModelOption>[kCodexDefaultModelOption];

/// Empty alias = send no model, so OpenCode uses the default of its own
/// config. Like codex's, it never goes stale; the real list comes from
/// `opencode models` (`RemoteModelCatalog`).
const kOpenCodeDefaultModelAlias = '';

const kOpenCodeModelOptions = <AgentModelOption>[
  AgentModelOption(
    alias: kOpenCodeDefaultModelAlias,
    label: 'El de tu config de OpenCode',
  ),
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
    AgentProvider.openCode => kOpenCodeModelOptions,
    AgentProvider.openRouter => kOpenRouterModelOptions,
    AgentProvider.deepSeek => kDeepSeekModelOptions,
  };
}

String defaultModelFor(AgentProvider provider) {
  return switch (provider) {
    AgentProvider.claude => kDefaultClaudeModelAlias,
    AgentProvider.codex => kCodexDefaultModelAlias,
    AgentProvider.openCode => kOpenCodeDefaultModelAlias,
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
  if (provider == AgentProvider.claude) {
    final label = alias.toClaudeModelLabel();
    if (label != null) return label;
  }
  return alias.isEmpty ? kCodexDefaultModelOption.label : alias;
}

extension AgentModelOptionList on List<AgentModelOption> {
  /// This list plus [alias] when it isn't in it: the model an agent is stored
  /// with stays selectable after its CLI stops listing it — a dropdown whose
  /// value is not among its items fails its own assertion.
  List<AgentModelOption> including(AgentProvider provider, String alias) =>
      any((option) => option.alias == alias)
      ? this
      : [
          ...this,
          AgentModelOption(alias: alias, label: modelLabelFor(provider, alias)),
        ];

  /// The label this list gives [alias]. A loaded catalog knows names the
  /// built-in one doesn't ("Opus 5.5", "GPT-6-Sol").
  String labelOf(AgentProvider provider, String alias) =>
      where((option) => option.alias == alias).firstOrNull?.label ??
      modelLabelFor(provider, alias);
}

/// A concrete Claude model id split into family and version:
/// `claude-opus-5-5` is `(family: 'opus', version: [5, 5])`.
typedef ClaudeModelVersion = ({String family, List<int> version});

extension ClaudeModelIdParsing on String {
  /// `claude-<family>-<version parts>`, where a version part is one or two
  /// digits: an eight-digit date suffix is not part of the version.
  static final _pattern = RegExp(r'^claude-([a-z]+)((?:-\d{1,2}(?!\d))*)');

  /// Null for anything not shaped like a concrete id — a family alias
  /// included.
  ClaudeModelVersion? toClaudeModelVersion() {
    final match = _pattern.firstMatch(this);
    if (match == null) return null;
    return (
      family: match.group(1)!,
      version: [
        for (final part in match.group(2)!.split('-'))
          if (part.isNotEmpty) int.parse(part),
      ],
    );
  }

  /// `claude-haiku-4-5-20251001` is "Haiku 4.5" and `claude-fable-5-1[1m]`
  /// is "Fable 5.1 · 1M".
  String? toClaudeModelLabel() {
    final label = toClaudeModelVersion()?.toLabel();
    if (label == null) return null;
    return endsWith('[1m]') ? '$label · 1M' : label;
  }
}

extension ClaudeModelVersionLabel on ClaudeModelVersion {
  /// "Opus 5.5" for `(family: 'opus', version: [5, 5])`.
  String toLabel() {
    final name = '${family[0].toUpperCase()}${family.substring(1)}';
    return version.isEmpty ? name : '$name ${version.join('.')}';
  }

  /// 5.5 is newer than 5, and 5 is newer than 4.8.
  bool isNewerThan(ClaudeModelVersion other) {
    for (var i = 0; i < version.length && i < other.version.length; i++) {
      if (version[i] != other.version[i]) return version[i] > other.version[i];
    }
    return version.length > other.version.length;
  }
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

/// A family alias or a concrete `claude-*` id. The prefix matters: the
/// catalog now learns Claude ids at runtime, and this check runs where no
/// catalog is loaded — before a codex turn is spawned.
bool isClaudeModelAlias(String alias) =>
    kClaudeModelOptions.any((option) => option.alias == alias) ||
    alias.startsWith('claude-');

/// The value for codex's `-m`, or null when nothing should be passed.
///
/// Guards the same legacy case at RUN time: agents created before the
/// catalogs were split still carry `sonnet`, and codex would fail on a model
/// name that isn't its own.
String? codexModelArgument(String model) {
  if (model.isEmpty || isClaudeModelAlias(model)) return null;
  return model;
}
