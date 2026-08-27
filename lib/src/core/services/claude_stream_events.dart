import 'dart:convert';

import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/core/services/turn_usage.dart';

/// El traductor del `stream-json` de claude, escrito UNA vez.
///
/// Estaba duplicado palabra por palabra en `ClaudeCliService._parseEvent` y en
/// `task_runner_isolate._parseEventToMessages`, que es por qué el chat 1:1 y
/// los proyectos se desincronizaban cada vez que el CLI agregaba algo. Devuelve
/// el formato de cable —mapas planos, que es lo único que cruza un puerto de
/// isolate— y cada consumidor lo tipa de su lado.
///
/// Guarda una sola cosa entre eventos: los `tool_use` de `Task` que vio. Sin
/// ese recuerdo no hay forma de saber cuál de los cientos de `tool_result` de
/// un turno es la devolución de un subagente, y habría que mandarlos todos por
/// el puerto para descartarlos del otro lado.
class ClaudeStreamReader {
  final Set<String> _subagentToolUseIds = {};

  /// Cuánto contexto ocupaba la ÚLTIMA llamada del hilo principal.
  ///
  /// No es lo mismo que la suma del turno, y confundirlos es lo que tenía al
  /// anillo clavado en rojo. El bloque `usage` del evento `result` es el
  /// agregado de TODAS las llamadas del turno, y como cada paso de
  /// herramienta reenvía la conversación entera, el mismo contexto se cuenta
  /// una vez por paso. Medido sobre una traza real: 58.638 tokens de contexto
  /// verdadero contra 347.037 sumados, casi seis veces más.
  ///
  /// Lo que llena la ventana es lo que entró en la última llamada, y eso está
  /// en el `usage` de cada evento `assistant`.
  int _latestContextTokens = 0;

  /// El modelo con el que arrancó el turno, para elegir el techo de contexto
  /// correcto entre las entradas de `modelUsage`.
  String _turnModel = '';

  List<Map<String, dynamic>> read(Map<String, dynamic> event) {
    // Un subagente habla con el id del `Task` que lo abrió. Sin esta rama su
    // texto y su pensamiento entran al buffer del padre y quedan firmados por
    // alguien que no los escribió.
    final parent = event['parent_tool_use_id'] as String?;
    if (parent != null && parent.isNotEmpty) {
      return _readSubagent(event, parent);
    }

    switch (event['type'] as String?) {
      case 'system':
        return switch (event['subtype']) {
          'init' => switch (event['session_id'] as String?) {
            null => const <Map<String, dynamic>>[],
            final sessionId => () {
              _turnModel = event['model'] as String? ?? '';
              return [
                {'type': 'sessionStarted', 'sessionId': sessionId},
              ];
            }(),
          },
          'permission_denied' => [
            {
              'type': 'permissionDenied',
              'toolName': event['tool_name'] as String? ?? 'desconocido',
              'message': event['message'] as String? ?? 'Permiso denegado.',
            },
          ],
          _ => const <Map<String, dynamic>>[],
        };

      // Un hook que bloquea NO llega como `permission_denied`: llega como el
      // resultado con error de la herramienta que frenó. Verificado contra el
      // CLI real. Por la misma puerta entra la devolución de un subagente.
      case 'user':
        return [..._hookBlock(event), ..._subagentResult(event)];

      case 'assistant':
        _rememberContextOf(event);
        final content = _messageContentBlocks(event);
        if (content.isEmpty) return const [];

        final events = <Map<String, dynamic>>[];
        final textBuffer = StringBuffer();
        for (final block in content) {
          switch (block['type']) {
            case 'thinking':
              final thinking = block['thinking'] as String?;
              if (thinking != null && thinking.isNotEmpty) {
                events.add({'type': 'reasoningChunk', 'text': thinking});
              }
            case 'text':
              textBuffer.write(block['text'] as String? ?? '');
            case 'tool_use':
              final name = block['name'] as String?;
              if (name == null) continue;
              final input = block['input'] as Map<String, dynamic>?;
              events.add({'type': 'toolUse', 'name': name, 'input': input});
              final opened = _subagentOpenedBy(block, name, input);
              if (opened != null) events.add(opened);
          }
        }
        final text = textBuffer.toString();
        if (text.isNotEmpty) {
          events.add({'type': 'assistantText', 'text': text});
        }
        return events;

      case 'result':
        final usage = readTurnUsage(event, turnModel: _turnModel);
        // Si el turno no dejó ninguna llamada del hilo principal, no hay
        // «última»: se cae al agregado, que es lo único que hay.
        final contextTokens = _latestContextTokens > 0
            ? _latestContextTokens
            : usedContextOf(usage);
        _latestContextTokens = 0;
        return [
          {
            'type': 'turnCompleted',
            'isError': event['is_error'] as bool,
            // Por qué paró, cuando el CLI lo dice. `error_max_turns` es el
            // tope de turnos agénticos: el trabajo quedó a mitad de camino y
            // sin esto llega al chat como un fallo cualquiera, así que nadie
            // se enteraría de que la causa es un número configurable.
            'stopReason': event['subtype'] as String? ?? '',
            'costUsd': usage.costUsd,
            'costReported': event['total_cost_usd'] is num,
            'durationMs': usage.durationMs,
            'model': usage.model,
            'inputTokens': usage.inputTokens,
            'outputTokens': usage.outputTokens,
            'cacheReadTokens': usage.cacheReadTokens,
            'cacheCreationTokens': usage.cacheCreationTokens,
            'tokensReported': event['usage'] is Map,
            'usageIsCumulative': false,
            'contextUsedTokens': contextTokens,
            'contextWindowTokens': usage.contextWindowTokens,
          },
          if (usage.contextWindowTokens > 0)
            {
              'type': 'contextUsage',
              'usedTokens': contextTokens,
              'contextWindowTokens': usage.contextWindowTokens,
            },
        ];

      default:
        return const [];
    }
  }

  /// El `Task` que abre un subagente, si este bloque lo es.
  ///
  /// Lo que se guarda es el pedido, no la etiqueta: hasta acá la app tiraba el
  /// `input` entero y dejaba la frase «Delegando tarea a un subagente», que es
  /// exactamente la información que no sirve.
  Map<String, dynamic>? _subagentOpenedBy(
    Map<String, dynamic> block,
    String name,
    Map<String, dynamic>? input,
  ) {
    if (name != 'Task') return null;
    final id = block['id'] as String?;
    if (id == null || id.isEmpty) return null;
    _subagentToolUseIds.add(id);

    final prompt = input?['prompt'] as String? ?? '';
    final description = input?['description'] as String? ?? '';
    return {
      'type': 'subagentStarted',
      'id': id,
      'agentType': input?['subagent_type'] as String? ?? 'subagente',
      'ask': description.isNotEmpty ? description : firstSentenceOf(prompt),
      'prompt': prompt,
    };
  }

  List<Map<String, dynamic>> _subagentResult(Map<String, dynamic> event) {
    final content = _messageContentBlocks(event);
    if (content.isEmpty) return const [];

    final events = <Map<String, dynamic>>[];
    for (final part in content) {
      if (part['type'] != 'tool_result') continue;
      final id = part['tool_use_id'] as String?;
      if (id == null || !_subagentToolUseIds.remove(id)) continue;
      events.add({
        'type': 'subagentFinished',
        'id': id,
        'result': _flatten(part['content']),
        'isError': part['is_error'] == true,
      });
    }
    return events;
  }

  List<Map<String, dynamic>> _readSubagent(
    Map<String, dynamic> event,
    String parentId,
  ) {
    if (event['type'] != 'assistant') return const [];
    final content = _messageContentBlocks(event);
    if (content.isEmpty) return const [];

    final events = <Map<String, dynamic>>[];
    final textBuffer = StringBuffer();
    for (final block in content) {
      switch (block['type']) {
        case 'thinking':
          final thinking = block['thinking'] as String?;
          if (thinking != null && thinking.isNotEmpty) {
            events.add({
              'type': 'subagentReasoning',
              'id': parentId,
              'text': thinking,
            });
          }
        case 'text':
          textBuffer.write(block['text'] as String? ?? '');
        case 'tool_use':
          final name = block['name'] as String?;
          if (name == null) continue;
          events.add({
            'type': 'subagentToolUse',
            'id': parentId,
            'name': name,
            'input': block['input'] as Map<String, dynamic>?,
          });
      }
    }
    final text = textBuffer.toString();
    if (text.isNotEmpty) {
      events.add({'type': 'subagentText', 'id': parentId, 'text': text});
    }
    return events;
  }

  /// El bloqueo de un hook de keel-ui, si este resultado de herramienta lo es.
  ///
  /// Se reconoce por la marca que dejan los wrappers, así que solo dispara con
  /// NUESTROS hooks: uno que el usuario tenga en su propia configuración no la
  /// lleva, y un error común de herramienta tampoco.
  List<Map<String, dynamic>> _hookBlock(Map<String, dynamic> event) {
    final content = _messageContentBlocks(event);
    if (content.isEmpty) return const [];

    for (final part in content) {
      if (part['type'] != 'tool_result') continue;
      final text = _flatten(part['content']);
      if (!text.contains(kHookDenialMarker)) continue;
      return [
        {
          'type': 'permissionDenied',
          'toolName':
              RegExp(r'PreToolUse:(\w+)').firstMatch(text)?.group(1) ??
              'la herramienta',
          'message': text,
        },
      ];
    }
    return const [];
  }

  /// Normaliza las dos formas que emite Claude Code para `message.content`.
  ///
  /// Los turnos normales usan una lista de bloques Anthropic. Los comandos de
  /// control, incluido `/compact`, pueden emitir el mensaje de confirmación
  /// como un [String] directo. La frontera del protocolo absorbe esa diferencia
  /// para que ningún consumidor tenga que hacer casts sobre datos del CLI.
  /// Anota el contexto de esta llamada del hilo principal.
  ///
  /// Solo llega acá lo que NO es de un subagente: los eventos con
  /// `parent_tool_use_id` se desvían antes, en [read]. Un subagente tiene su
  /// propia conversación, y su tamaño no dice nada del contexto de esta.
  void _rememberContextOf(Map<String, dynamic> event) {
    final message = event['message'];
    if (message is! Map) return;
    final usage = message['usage'];
    if (usage is! Map) return;

    int read(String key) => (usage[key] as num? ?? 0).toInt();
    final total =
        read('input_tokens') +
        read('cache_read_input_tokens') +
        read('cache_creation_input_tokens');
    if (total > 0) _latestContextTokens = total;
  }

  static List<Map<String, dynamic>> _messageContentBlocks(
    Map<String, dynamic> event,
  ) {
    final message = event['message'];
    if (message is! Map) return const [];

    final content = message['content'];
    if (content is String) {
      if (content.isEmpty) return const [];
      return [
        {'type': 'text', 'text': content},
      ];
    }
    if (content is! List) return const [];

    return [
      for (final block in content)
        if (block is Map<String, dynamic>) block,
    ];
  }

  static String _flatten(Object? content) =>
      content is String ? content : jsonEncode(content);
}

/// La primera frase de un texto, recortada a algo que entre en un cuadro.
///
/// Es lo que el mapa muestra como «qué resolvió». Pedirle al modelo que se
/// resuma cuesta otro turno y puede mentir sobre lo que hizo; su primera frase
/// no puede.
///
/// Sale sin marcas de markdown. Un cuadro de dos líneas no puede renderizarlo
/// —no hay lugar para un encabezado— así que lo único que hacían las
/// almohadillas y los asteriscos ahí era gastar caracteres y verse rotos.
String firstSentenceOf(String text, {int maxLength = 120}) {
  final flat = stripMarkdown(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';

  final end = RegExp(r'[.!?](\s|$)').firstMatch(flat);
  final sentence = end == null ? flat : flat.substring(0, end.start + 1);
  if (sentence.length <= maxLength) return sentence;
  final cut = sentence.lastIndexOf(' ', maxLength);
  return '${sentence.substring(0, cut < 40 ? maxLength : cut)}…';
}

/// El texto sin las marcas de markdown, para los lugares que lo muestran
/// crudo.
///
/// No es un renderizador ni pretende serlo: es lo que hace falta para que un
/// cierre que empieza con `## Cierre del paso 3` se lea «Cierre del paso 3»
/// en un cuadro de dos líneas. Donde SÍ hay lugar para renderizarlo —la ficha
/// de un nodo, el hilo, una burbuja— no se llama a esto: se muestra el texto
/// entero con `MarkdownText`.
String stripMarkdown(String text) {
  var out = text;
  // Reglas horizontales: solas en su línea, no dicen nada aplanadas.
  out = out.replaceAll(RegExp(r'^\s*([-*_])\1{2,}\s*$', multiLine: true), '');
  // Encabezados y citas al empezar la línea.
  out = out.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
  out = out.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
  // Viñetas y numeración: la marca se va, el punto queda.
  out = out.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  out = out.replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '');
  // Enlaces e imágenes: queda el texto, que es lo que se lee. Con
  // `replaceAllMapped` y no con `replaceAll`: el segundo escribe `$1`
  // literal, porque en Dart el reemplazo es una cadena y no un patrón.
  out = out.replaceAllMapped(
    RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  // Énfasis y código. El backtick se saca sin dejar nada: `orden` se lee
  // igual, y en un cuadro chico las comillas son ruido.
  out = out.replaceAll(RegExp(r'\*\*|__|`+'), '');
  return out;
}
