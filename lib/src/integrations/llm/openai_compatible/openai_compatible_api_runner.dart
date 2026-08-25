import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_tool_bridge.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

typedef LlmSecretResolver = Future<String?> Function(String secretRef);

/// Runner for providers implementing OpenAI-compatible Chat Completions.
///
/// Tools are never executed directly from model output: [OpenAiToolBridge]
/// publishes only the functions granted to the turn, validates every call,
/// and preserves Keel's workspace scope, hooks, and MCP configuration.
class OpenAiCompatibleApiRunner implements LlmRunner {
  final String baseUrl;
  final String secretRef;
  final String? _apiKey;
  final http.Client? _client;
  final LlmSecretResolver? _resolveSecret;
  final OpenAiToolBridge? _toolBridge;
  final int maxToolRounds;

  const OpenAiCompatibleApiRunner({
    required this.baseUrl,
    required this.secretRef,
    String? apiKey,
    http.Client? client,
    LlmSecretResolver? resolveSecret,
    OpenAiToolBridge? toolBridge,
    this.maxToolRounds = 12,
  }) : // Public constructor names keep infrastructure injectable in tests.
       // ignore: prefer_initializing_formals
       _apiKey = apiKey,
       // ignore: prefer_initializing_formals
       _client = client,
       // ignore: prefer_initializing_formals
       _resolveSecret = resolveSecret,
       // ignore: prefer_initializing_formals
       _toolBridge = toolBridge;

  @override
  Stream<LlmEvent> run(
    LlmTurnSpec spec, {
    required String userPath,
    required Stream<void> cancel,
    void Function(int pid)? onPidKnown,
  }) async* {
    final started = Stopwatch()..start();
    var cancelled = false;
    final client = _client ?? http.Client();
    final toolBridge = _toolBridge ?? DefaultOpenAiToolBridge();
    final cancelSubscription = cancel.listen((_) {
      cancelled = true;
      client.close();
    });

    try {
      final resolver = _resolveSecret;
      final secret =
          _apiKey ?? (resolver == null ? null : await resolver(secretRef));
      if (secret == null || secret.isEmpty) {
        yield {
          'type': 'failure',
          'message': 'Falta configurar el secret $secretRef.',
        };
        yield _completed(
          spec,
          started,
          isError: true,
          hasReportedFailure: true,
        );
        return;
      }
      if (cancelled) return;

      final functions = await toolBridge.functions(spec);
      if (cancelled) return;
      final messages = <Map<String, dynamic>>[
        if (spec.additionalSystemPrompt case final prompt?
            when prompt.isNotEmpty)
          {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': spec.prompt},
      ];
      var usage = const _OpenAiCompatibleUsage();
      String? lastSuccessfulToolSignature;
      String? warnedSterileToolSignature;

      for (var round = 0; round <= maxToolRounds; round++) {
        final response = await _send(
          client: client,
          secret: secret,
          spec: spec,
          messages: messages,
          functions: functions,
        );
        if (cancelled) return;
        if (response.statusCode >= 400) {
          final body = await response.stream.bytesToString();
          yield {
            'type': 'failure',
            'message': '${response.statusCode} · ${_firstLine(body)}',
          };
          yield _completed(
            spec,
            started,
            isError: true,
            usage: usage,
            hasReportedFailure: true,
          );
          return;
        }

        final parsed = _StreamingRound();
        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          if (cancelled) return;
          final payload = _ssePayload(line);
          if (payload == null) continue;
          if (payload == '[DONE]') {
            parsed.completed = true;
            break;
          }
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) continue;
          parsed.add(decoded);
          for (final event in parsed.drainEvents()) {
            yield event;
          }
        }
        usage = usage + parsed.usage;

        if (!parsed.completed) {
          yield {
            'type': 'failure',
            'message': 'El stream del proveedor terminó sin [DONE].',
          };
          yield _completed(
            spec,
            started,
            isError: true,
            usage: usage,
            hasReportedFailure: true,
          );
          return;
        }

        final calls = parsed.toolCalls;
        if (calls.isEmpty) {
          yield _completed(spec, started, isError: false, usage: usage);
          return;
        }
        if (round == maxToolRounds) {
          final roundsLabel = maxToolRounds == 1 ? 'ronda' : 'rondas';
          yield {
            'type': 'failure',
            'message':
                'Keel detuvo el ciclo de herramientas al alcanzar el límite '
                'seguro de $maxToolRounds $roundsLabel.',
          };
          yield _completed(
            spec,
            started,
            isError: true,
            usage: usage,
            hasReportedFailure: true,
          );
          return;
        }

        messages.add(parsed.assistantToolMessage());
        for (final call in calls) {
          final arguments = call.decodedArguments;
          yield {'type': 'toolUse', 'name': call.name, 'input': arguments};
          final signature = arguments == null
              ? null
              : _toolCallSignature(call.name, arguments);
          if (signature != null &&
              signature == lastSuccessfulToolSignature &&
              warnedSterileToolSignature == signature) {
            yield {
              'type': 'failure',
              'message':
                  'El proveedor insistió en un reintento estéril de '
                  '${call.name} después de que Keel lo rechazó. Cambiá el '
                  'plan o usá la evidencia ya obtenida.',
            };
            yield _completed(
              spec,
              started,
              isError: true,
              usage: usage,
              hasReportedFailure: true,
            );
            return;
          }
          final result = switch (arguments) {
            null => OpenAiToolResult(
              content: jsonEncode({
                'ok': false,
                'error': 'Argumentos JSON inválidos para ${call.name}.',
              }),
              isError: true,
            ),
            _ when signature == lastSuccessfulToolSignature => OpenAiToolResult(
              content: jsonEncode({
                'ok': false,
                'error':
                    'Reintento estéril rechazado: ${call.name} recibió la '
                    'misma herramienta y argumentos sin cambio de contexto. '
                    'Reformulá el plan o respondé con la evidencia disponible.',
              }),
              isError: true,
            ),
            _ => await toolBridge.execute(spec, call.name, arguments),
          };
          if (cancelled) return;
          if (signature != null && signature == lastSuccessfulToolSignature) {
            warnedSterileToolSignature = signature;
          } else if (!result.isError && signature != null) {
            lastSuccessfulToolSignature = signature;
            warnedSterileToolSignature = null;
          } else {
            lastSuccessfulToolSignature = null;
            warnedSterileToolSignature = null;
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': result.content,
          });
        }
      }
    } catch (error) {
      if (!cancelled) {
        Log.e('OpenAI-compatible API turn failed', error: error);
        yield {'type': 'failure', 'message': 'Falló la API LLM: $error'};
        yield _completed(
          spec,
          started,
          isError: true,
          hasReportedFailure: true,
        );
      }
    } finally {
      await cancelSubscription.cancel();
      await toolBridge.close();
      if (_client == null) client.close();
    }
  }

  Future<http.StreamedResponse> _send({
    required http.Client client,
    required String secret,
    required LlmTurnSpec spec,
    required List<Map<String, dynamic>> messages,
    required List<OpenAiFunctionDefinition> functions,
  }) {
    final request = http.Request('POST', _chatCompletionsUri(baseUrl))
      ..headers.addAll({
        'Authorization': 'Bearer $secret',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': spec.model,
        'stream': true,
        'stream_options': {'include_usage': true},
        'messages': messages,
        if (functions.isNotEmpty) ...{
          'tools': functions.map((function) => function.toJson()).toList(),
          'tool_choice': 'auto',
        },
      });
    return client.send(request);
  }

  LlmEvent _completed(
    LlmTurnSpec spec,
    Stopwatch started, {
    required bool isError,
    _OpenAiCompatibleUsage usage = const _OpenAiCompatibleUsage(),
    bool hasReportedFailure = false,
  }) => {
    'type': 'turnCompleted',
    'isError': isError,
    if (hasReportedFailure) 'hasReportedFailure': true,
    'costUsd': usage.costUsd ?? 0.0,
    if (usage.costUsd != null) 'costReported': true,
    'durationMs': started.elapsedMilliseconds,
    'model': spec.model,
    'inputTokens': usage.inputTokens,
    'outputTokens': usage.outputTokens,
    'cacheReadTokens': usage.cacheReadTokens,
    'cacheCreationTokens': usage.cacheCreationTokens,
    if (usage.reported) ...{
      'tokensReported': true,
      'usageIsCumulative': false,
      'contextUsedTokens': usage.latestContextTokens,
      'contextWindowTokens': 0,
    },
  };
}

String _toolCallSignature(String name, Map<String, dynamic> arguments) =>
    '$name\n${jsonEncode(_canonicalJson(arguments))}';

Object? _canonicalJson(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.map((key) => '$key').toList()..sort())
      key: _canonicalJson(value[key]),
  },
  List() => [for (final item in value) _canonicalJson(item)],
  _ => value,
};

class _StreamingRound {
  final List<LlmEvent> _events = [];
  final Map<int, _PendingToolCall> _calls = {};
  final StringBuffer _text = StringBuffer();
  final StringBuffer _reasoning = StringBuffer();
  _OpenAiCompatibleUsage usage = const _OpenAiCompatibleUsage();
  bool completed = false;

  List<_PendingToolCall> get toolCalls => [
    for (final entry
        in _calls.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)))
      entry.value,
  ];

  void add(Map<String, dynamic> chunk) {
    usage = _OpenAiCompatibleUsage.fromJson(chunk['usage']) ?? usage;
    final choices = chunk['choices'] as List?;
    if (choices == null) return;
    for (final rawChoice in choices.whereType<Map>()) {
      final choice = rawChoice.cast<String, dynamic>();
      final delta = (choice['delta'] as Map?)?.cast<String, dynamic>();
      if (delta == null) continue;
      final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
      if (reasoning is String && reasoning.isNotEmpty) {
        _reasoning.write(reasoning);
        _events.add({'type': 'reasoningChunk', 'text': reasoning});
      }
      final text = delta['content'];
      if (text is String && text.isNotEmpty) {
        _text.write(text);
        _events.add({'type': 'assistantText', 'text': text});
      }
      for (final rawCall in delta['tool_calls'] as List? ?? const []) {
        if (rawCall is! Map) continue;
        final call = rawCall.cast<String, dynamic>();
        final index = call['index'] as int? ?? 0;
        final pending = _calls.putIfAbsent(index, _PendingToolCall.new);
        final id = call['id'];
        if (id is String && id.isNotEmpty) pending.id = id;
        final function = (call['function'] as Map?)?.cast<String, dynamic>();
        final name = function?['name'];
        if (name is String) pending.nameBuffer.write(name);
        final arguments = function?['arguments'];
        if (arguments is String) pending.argumentsBuffer.write(arguments);
      }
    }
  }

  List<LlmEvent> drainEvents() {
    final result = List<LlmEvent>.of(_events);
    _events.clear();
    return result;
  }

  Map<String, dynamic> assistantToolMessage() => {
    'role': 'assistant',
    'content': _text.toString().isEmpty ? null : _text.toString(),
    if (_reasoning.isNotEmpty) 'reasoning_content': _reasoning.toString(),
    'tool_calls': toolCalls.map((call) => call.toJson()).toList(),
  };
}

class _PendingToolCall {
  String id = '';
  final StringBuffer nameBuffer = StringBuffer();
  final StringBuffer argumentsBuffer = StringBuffer();

  String get name => nameBuffer.toString();

  Map<String, dynamic>? get decodedArguments {
    try {
      final decoded = jsonDecode(argumentsBuffer.toString());
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': argumentsBuffer.toString()},
  };
}

class _OpenAiCompatibleUsage {
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final int latestContextTokens;
  final double? costUsd;
  final bool reported;

  const _OpenAiCompatibleUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
    this.latestContextTokens = 0,
    this.costUsd,
    this.reported = false,
  });

  _OpenAiCompatibleUsage operator +(_OpenAiCompatibleUsage other) =>
      _OpenAiCompatibleUsage(
        inputTokens: inputTokens + other.inputTokens,
        outputTokens: outputTokens + other.outputTokens,
        cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
        cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens,
        latestContextTokens: other.reported
            ? other.latestContextTokens
            : latestContextTokens,
        costUsd: costUsd == null && other.costUsd == null
            ? null
            : (costUsd ?? 0) + (other.costUsd ?? 0),
        reported: reported || other.reported,
      );

  static _OpenAiCompatibleUsage? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final promptDetails = (json['prompt_tokens_details'] as Map?)
        ?.cast<String, dynamic>();
    final promptTokens = _usageInt(json['prompt_tokens']);
    final cacheReadTokens = _usageInt(
      promptDetails?['cached_tokens'] ?? json['prompt_cache_hit_tokens'],
    );
    final cacheCreationTokens = _usageInt(promptDetails?['cache_write_tokens']);
    return _OpenAiCompatibleUsage(
      inputTokens: (promptTokens - cacheReadTokens - cacheCreationTokens).clamp(
        0,
        promptTokens,
      ),
      outputTokens: _usageInt(json['completion_tokens']),
      cacheReadTokens: cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens,
      latestContextTokens: promptTokens,
      costUsd: (json['cost'] as num?)?.toDouble(),
      reported: true,
    );
  }
}

int _usageInt(Object? value) => (value as num?)?.toInt() ?? 0;

Uri _chatCompletionsUri(String baseUrl) {
  final uri = Uri.parse(baseUrl);
  final cleanSegments = [
    ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    'chat',
    'completions',
  ];
  return uri.replace(pathSegments: cleanSegments);
}

String? _ssePayload(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('data:')) return null;
  return trimmed.substring(5).trim();
}

String _firstLine(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'sin cuerpo';
  final line = const LineSplitter().convert(trimmed).first;
  return line.length > 160 ? '${line.substring(0, 160)}...' : line;
}

/// Shared by the runner and the remote model picker. It intentionally returns
/// only the requested secret, never the vault object or another secret value.
Future<String?> resolveLlmSecret(String secretRef) =>
    SecretsService.instance.notifier.resolveValue(secretRef);
