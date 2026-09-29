import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/user_shell_path.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Small, cache-backed catalog used by the provider picker. A catalog failure
/// never hides the current model: callers retain the static safe defaults.
///
/// API providers are asked over HTTP. Codex is asked through its own CLI
/// (`codex debug models`); the Claude CLI has no listing command, so its
/// catalog is read from what it already keeps on this machine.
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
    Future<String?> Function()? codexCatalog,
    Future<String?> Function()? openCodeCatalog,
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
       _observedModels = observedModels,
       // ignore: prefer_initializing_formals
       _codexCatalog = codexCatalog,
       // ignore: prefer_initializing_formals
       _openCodeCatalog = openCodeCatalog;

  /// Sorts after every ranked model: codex ranks its picker by `priority`.
  static const _unranked = 1 << 30;

  final http.Client? _client;
  final LlmSecretResolver _resolveSecret;
  final String? _homeDirectory;
  final String? _codexHome;
  final Future<List<String>> Function()? _observedModels;

  /// The raw JSON `codex debug models` would print. Null: ask the CLI.
  final Future<String?> Function()? _codexCatalog;

  /// The raw text `opencode models --verbose` would print. Null: ask it.
  final Future<String?> Function()? _openCodeCatalog;
  final Map<AgentProvider, List<AgentModelOption>> _cache = {};

  Future<List<AgentModelOption>> load(AgentProvider provider) async {
    final cached = _cache[provider];
    if (cached != null) return cached;
    final options = switch (provider) {
      AgentProvider.claude => await _claudeModels(),
      AgentProvider.codex => await _codexModels(),
      AgentProvider.openCode => await _openCodeModels(),
      AgentProvider.openRouter => await _openRouterModels(),
      AgentProvider.deepSeek => await _deepSeekModels(),
    };
    _cache[provider] = options.isEmpty ? modelOptionsFor(provider) : options;
    return _cache[provider]!;
  }

  void clear(AgentProvider provider) => _cache.remove(provider);

  String get _home => _homeDirectory ?? Platform.environment['HOME'] ?? '';

  /// What `opencode models --verbose` lists that can call tools — a model
  /// that cannot is useless to an agent. Each model's variants are its
  /// effort levels.
  Future<List<AgentModelOption>> _openCodeModels() async {
    final source = await (_openCodeCatalog ?? _openCodeListing)();
    if (source == null) return const [];
    final models = await runOffThread(_parseOpenCodeCatalog, source);
    if (models.isEmpty) {
      Log.w('`opencode models` listed nothing usable');
      return const [];
    }
    return [...kOpenCodeModelOptions, ...models];
  }

  Future<String?> _openCodeListing() async {
    final opencode = await UserShellPath.locate('opencode');
    if (opencode == null) {
      Log.w('opencode is not on the PATH: no OpenCode model catalog');
      return null;
    }
    try {
      final result = await Process.run(
        opencode,
        const ['models', '--verbose'],
        environment: await UserShellPath.environment(),
        stdoutEncoding: utf8,
      ).timeout(const Duration(seconds: 30));
      if (result.exitCode == 0) return '${result.stdout}';
      Log.w(
        '`opencode models` exited ${result.exitCode}: '
        '${'${result.stderr}'.trim()}',
      );
    } on Object catch (error) {
      Log.w('`opencode models` failed: $error');
    }
    return null;
  }

  /// `opencode models --verbose` prints `provider/model` on its own line and
  /// then that model's JSON, pretty-printed, closing with `}` at column 0.
  static List<AgentModelOption> _parseOpenCodeCatalog(String source) {
    final options = <AgentModelOption>[];
    String? id;
    final block = StringBuffer();
    for (final line in const LineSplitter().convert(source)) {
      if (id == null) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('{')) id = trimmed;
        continue;
      }
      block.writeln(line);
      if (line != '}') continue;
      final decoded = _tryDecode(block.toString());
      block.clear();
      final alias = id;
      id = null;
      if (decoded is! Map) continue;
      final capabilities = decoded['capabilities'];
      if (capabilities is Map && capabilities['toolcall'] == false) continue;
      options.add(
        AgentModelOption(
          alias: alias,
          label: switch (decoded['name']) {
            final String name when name.isNotEmpty => '$name · $alias',
            _ => alias,
          },
          efforts: [
            if (decoded['variants'] case final Map variants)
              for (final variant in variants.keys) '$variant',
          ],
        ),
      );
    }
    return options;
  }

  /// What `codex debug models` lists — asked of the SAME binary that runs
  /// the turns. Reading `models_cache.json` instead offered models the
  /// installed CLI does not know: another codex (the desktop app, a newer
  /// version) writes that file too, and its catalog is not this one's.
  Future<List<AgentModelOption>> _codexModels() async {
    final source = await (_codexCatalog ?? _codexDebugModels)();
    if (source == null) return const [];
    final models = await runOffThread(_parseCodexCatalog, source);
    if (models.isEmpty) {
      Log.w('`codex debug models` listed nothing usable');
      return const [];
    }
    return [kCodexDefaultModelOption, ...models];
  }

  Future<String?> _codexDebugModels() async {
    final codex = await UserShellPath.locate('codex');
    if (codex == null) {
      Log.w('codex is not on the PATH: no codex model catalog');
      return null;
    }
    final ProcessResult result;
    try {
      result = await Process.run(
        codex,
        const ['debug', 'models'],
        environment: {
          ...await UserShellPath.environment(),
          if (_codexHome != null) 'CODEX_HOME': _codexHome,
        },
        stdoutEncoding: utf8,
      ).timeout(const Duration(seconds: 20));
    } on Object catch (error) {
      Log.w('`codex debug models` failed: $error');
      return null;
    }
    if (result.exitCode != 0) {
      Log.w(
        '`codex debug models` exited ${result.exitCode}: '
        '${'${result.stderr}'.trim()}',
      );
      return null;
    }
    return '${result.stdout}';
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
  /// order, each with the reasoning levels it accepts. Static so it can run
  /// off the UI thread — the catalog is hundreds of KB.
  static List<AgentModelOption> _parseCodexCatalog(String source) {
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
                efforts: [
                  for (final level
                      in (model['supported_reasoning_levels'] as List? ??
                              const [])
                          .whereType<Map>())
                    if (level['effort'] case final String effort) effort,
                ],
                defaultEffort: model['default_reasoning_level'] as String?,
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
