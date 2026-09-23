import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Small, cache-backed catalog used by the provider picker. A catalog failure
/// never hides the current model: callers retain the static safe defaults.
///
/// API providers are asked over HTTP. The two CLIs have no model-listing
/// endpoint Keel can call, so their catalogs are read from what each CLI
/// already keeps on this machine.
// keel-debt: lives under openai_compatible/ and each picker owns an instance
// (re-reads the CLI files once per picker), move to integrations/llm/ as one
// shared service if pickers multiply or the files grow.
class RemoteModelCatalog {
  RemoteModelCatalog({
    http.Client? client,
    LlmSecretResolver resolveSecret = resolveLlmSecret,
    String? homeDirectory,
    String? codexHome,
    Future<List<String>> Function()? observedModels,
    // Public parameter names are part of the testable adapter contract.
    // ignore: prefer_initializing_formals
  }) : _client = client,
       // ignore: prefer_initializing_formals
       _resolveSecret = resolveSecret,
       // ignore: prefer_initializing_formals
       _homeDirectory = homeDirectory,
       // ignore: prefer_initializing_formals
       _codexHome = codexHome,
       // ignore: prefer_initializing_formals
       _observedModels = observedModels;

  /// Sorts after every ranked model: codex ranks its picker by `priority`.
  static const _unranked = 1 << 30;

  final http.Client? _client;
  final LlmSecretResolver _resolveSecret;
  final String? _homeDirectory;
  final String? _codexHome;
  final Future<List<String>> Function()? _observedModels;
  final Map<AgentProvider, List<AgentModelOption>> _cache = {};

  Future<List<AgentModelOption>> load(AgentProvider provider) async {
    final cached = _cache[provider];
    if (cached != null) return cached;
    final options = switch (provider) {
      AgentProvider.claude => await _claudeModels(),
      AgentProvider.codex => await _codexModels(),
      AgentProvider.openRouter => await _openRouterModels(),
      AgentProvider.deepSeek => await _deepSeekModels(),
    };
    _cache[provider] = options.isEmpty ? modelOptionsFor(provider) : options;
    return _cache[provider]!;
  }

  void clear(AgentProvider provider) => _cache.remove(provider);

  String get _home => _homeDirectory ?? Platform.environment['HOME'] ?? '';

  String get _codexDirectory =>
      _codexHome ?? Platform.environment['CODEX_HOME'] ?? '$_home/.codex';

  /// Codex refreshes `models_cache.json` itself on every run, so reading it
  /// is what makes a new codex model show up here without a Keel release.
  Future<List<AgentModelOption>> _codexModels() async {
    final path = '$_codexDirectory/models_cache.json';
    final source = await _readIfPresent(path);
    if (source == null) return const [];
    final models = await runOffThread(_parseCodexModelsCache, source);
    if (models.isEmpty) {
      Log.w(
        'Codex model catalog at $path is unreadable; using the built-in list',
      );
      return const [];
    }
    return [kCodexDefaultModelOption, ...models];
  }

  /// The Claude CLI has no command that lists models, and a subscription
  /// login carries no API key to ask Anthropic with. What this machine does
  /// know: the family aliases (always the newest of each family), the version
  /// each one actually ran as — the usage ledger records it from every
  /// turn's `system/init` — and the extra options the CLI caches for this
  /// account in `~/.claude.json`.
  Future<List<AgentModelOption>> _claudeModels() async {
    final observed = await (_observedModels ?? _ledgerClaudeModels)();
    final source = await _readIfPresent('$_home/.claude.json');
    final extras = source == null
        ? const <AgentModelOption>[]
        : await runOffThread(_parseClaudeExtraModels, source);
    return _claudeModelOptions(observed: observed, extras: extras);
  }

  static Future<List<String>> _ledgerClaudeModels() async {
    final ledger = UsageLedgerService.instance.notifier;
    await ledger.ready;
    return [
      for (final entry in ledger.data.entries)
        if (entry.provider == AgentProvider.claude.alias) entry.model,
    ];
  }

  /// Null when the file is not there — a CLI that was never run on this
  /// machine is the normal case, not an error. Any other read failure is
  /// logged: the picker still falls back, but the cause stays visible.
  static Future<String?> _readIfPresent(String path) async {
    try {
      return await File(path).readAsString();
    } on PathNotFoundException {
      return null;
    } on FileSystemException catch (error) {
      Log.w('Could not read the model catalog at $path: ${error.message}');
      return null;
    }
  }

  /// The entries codex's own picker offers (`visibility: list`), in its
  /// order. Static so it can run off the UI thread — the file is hundreds of
  /// KB.
  static List<AgentModelOption> _parseCodexModelsCache(String source) {
    final decoded = _tryDecode(source);
    final models = decoded is Map ? decoded['models'] : null;
    if (models is! List) return const [];
    final listed = [
      for (final (index, model) in models.whereType<Map>().indexed)
        if (model['visibility'] == 'list')
          if (model['slug'] case final String slug when slug.isNotEmpty)
            (
              priority: switch (model['priority']) {
                final int value => value,
                _ => _unranked,
              },
              index: index,
              option: AgentModelOption(
                alias: slug,
                label: switch (model['display_name']) {
                  final String name when name.isNotEmpty => name,
                  _ => slug,
                },
              ),
            ),
    ];
    // `List.sort` is not stable: the file order breaks priority ties.
    listed.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : a.index.compareTo(b.index);
    });
    return [for (final entry in listed) entry.option];
  }

  /// The extra picker options the Claude CLI caches for this account under
  /// `additionalModelOptionsCache` — e.g. Fable 5.1 with the 1M context
  /// window. It is an internal cache of the CLI, so an entry that isn't
  /// shaped as expected is skipped, never trusted.
  static List<AgentModelOption> _parseClaudeExtraModels(String source) {
    final decoded = _tryDecode(source);
    final entries = decoded is Map
        ? decoded['additionalModelOptionsCache']
        : null;
    if (entries is! List) return const [];
    return [
      for (final entry in entries.whereType<Map>())
        if (entry['value'] case final String value when value.isNotEmpty)
          AgentModelOption(
            alias: value,
            label:
                value.toClaudeModelLabel() ??
                switch (entry['label']) {
                  final String label when label.isNotEmpty => label,
                  _ => value,
                },
          ),
    ];
  }

  /// The family aliases, each labelled with the newest version seen running
  /// under it, followed by the account's extra options that aren't already
  /// one of them. A family never seen keeps its bare name: a guessed version
  /// number would be exactly the stale label this replaces.
  static List<AgentModelOption> _claudeModelOptions({
    required List<String> observed,
    required List<AgentModelOption> extras,
  }) {
    final newest = <String, ClaudeModelVersion>{};
    for (final id in observed) {
      final seen = id.toClaudeModelVersion();
      if (seen == null) continue;
      final current = newest[seen.family];
      if (current == null || seen.isNewerThan(current)) {
        newest[seen.family] = seen;
      }
    }
    final options = <String, AgentModelOption>{
      for (final family in kClaudeModelOptions)
        family.alias: switch (newest[family.alias]) {
          final seen? => AgentModelOption(
            alias: family.alias,
            label: seen.toLabel(),
          ),
          null => family,
        },
    };
    for (final extra in extras) {
      options.putIfAbsent(extra.alias, () => extra);
    }
    return options.values.toList();
  }

  static Object? _tryDecode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  Future<List<AgentModelOption>> _openRouterModels() async {
    return _load(
      provider: AgentProvider.openRouter,
      uri: Uri.parse(
        'https://openrouter.ai/api/v1/models?supported_parameters=tools',
      ),
      parse: (json) {
        final data = json['data'] as List? ?? const [];
        return [
          for (final entry in data.whereType<Map>())
            if (entry['id'] case final String id when id.isNotEmpty)
              AgentModelOption(
                alias: id,
                label: entry['name'] as String? ?? id,
              ),
        ];
      },
    );
  }

  Future<List<AgentModelOption>> _deepSeekModels() async {
    return _load(
      provider: AgentProvider.deepSeek,
      uri: Uri.parse('https://api.deepseek.com/models'),
      parse: (json) {
        final data = json['data'] as List? ?? const [];
        return [
          for (final entry in data.whereType<Map>())
            if (entry['id'] case final String id when id.isNotEmpty)
              AgentModelOption(alias: id, label: id),
        ];
      },
    );
  }

  Future<List<AgentModelOption>> _load({
    required AgentProvider provider,
    required Uri uri,
    required List<AgentModelOption> Function(Map<String, dynamic> json) parse,
  }) async {
    final secretName = provider.secretName;
    if (secretName == null) return const [];
    final secret = await _resolveSecret(secretName);
    if (secret == null || secret.isEmpty) return const [];
    final owned = _client == null;
    final client = _client ?? http.Client();
    try {
      final response = await client.get(
        uri,
        headers: {'Authorization': 'Bearer $secret'},
      );
      if (response.statusCode >= 400) return const [];
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? parse(decoded) : const [];
    } finally {
      if (owned) client.close();
    }
  }
}
