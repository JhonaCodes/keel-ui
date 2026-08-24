import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// Small, cache-backed catalog used by the provider picker. A catalog failure
/// never hides the current model: callers retain the static safe defaults.
class RemoteModelCatalog {
  RemoteModelCatalog({
    http.Client? client,
    LlmSecretResolver resolveSecret = resolveLlmSecret,
    // Public parameter names are part of the testable adapter contract.
    // ignore: prefer_initializing_formals
  }) : _client = client,
       // ignore: prefer_initializing_formals
       _resolveSecret = resolveSecret;

  final http.Client? _client;
  final LlmSecretResolver _resolveSecret;
  final Map<AgentProvider, List<AgentModelOption>> _cache = {};

  Future<List<AgentModelOption>> load(AgentProvider provider) async {
    final cached = _cache[provider];
    if (cached != null) return cached;
    final options = switch (provider) {
      AgentProvider.openRouter => await _openRouterModels(),
      AgentProvider.deepSeek => await _deepSeekModels(),
      _ => modelOptionsFor(provider),
    };
    _cache[provider] = options.isEmpty ? modelOptionsFor(provider) : options;
    return _cache[provider]!;
  }

  void clear(AgentProvider provider) => _cache.remove(provider);

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
