/// Lo que el CLI informa cuando cierra un turno.
///
/// Estaba escrito dos veces, palabra por palabra: una en `ClaudeCliService`
/// y otra en el isolate del task runner, que arma mapas en vez de objetos
/// porque tienen que cruzar la frontera del isolate. Lo que compartían no
/// era la forma sino la LECTURA, así que eso es lo que quedó acá.
///
/// Es puro y sin dependencias: entra el evento `result` tal como llegó,
/// salen los números.
library;

/// Los contadores de un turno, ya sumados.
typedef TurnUsage = ({
  double costUsd,
  int durationMs,

  /// El modelo que realmente condujo el turno.
  String model,

  int inputTokens,
  int outputTokens,
  int cacheReadTokens,
  int cacheCreationTokens,

  /// El techo de contexto del modelo, o 0 si el CLI no lo informó.
  int contextWindowTokens,
});

/// Cuánto contexto ocupa el turno: entrada más caché.
///
/// La salida no cuenta, y no es un olvido: lo que llena la ventana es lo que
/// entra, y los tokens generados ya están contados adentro del input del
/// turno siguiente.
int usedContextOf(TurnUsage usage) =>
    usage.inputTokens + usage.cacheReadTokens + usage.cacheCreationTokens;

/// Lee el evento `result` del stream del CLI.
TurnUsage readTurnUsage(Map<String, dynamic> event) {
  final usage = event['usage'] as Map<String, dynamic>?;
  final main = _mainModelUsage(event['modelUsage'] as Map<String, dynamic>?);

  return (
    costUsd: (event['total_cost_usd'] as num?)?.toDouble() ?? 0,
    durationMs: event['duration_ms'] as int? ?? 0,
    model: main?.model ?? '',
    inputTokens: _int(usage?['input_tokens']),
    outputTokens: _int(usage?['output_tokens']),
    cacheReadTokens: _int(usage?['cache_read_input_tokens']),
    cacheCreationTokens: _int(usage?['cache_creation_input_tokens']),
    contextWindowTokens: _int(main?.entry['contextWindow']),
  );
}

int _int(Object? value) => (value as num? ?? 0).toInt();

/// La entrada de `modelUsage` con más uso: ese es el modelo que condujo el
/// turno, y no las llamadas internas chiquitas (un haiku de fondo, por
/// ejemplo) que también aparecen en el mapa.
({String model, Map<String, dynamic> entry})? _mainModelUsage(
  Map<String, dynamic>? modelUsage,
) {
  if (modelUsage == null) return null;

  ({String model, Map<String, dynamic> entry})? best;
  var bestTotal = -1;
  for (final pair in modelUsage.entries) {
    final entry = pair.value as Map<String, dynamic>;
    final total =
        _int(entry['inputTokens']) +
        _int(entry['cacheReadInputTokens']) +
        _int(entry['cacheCreationInputTokens']);
    if (total > bestTotal) {
      bestTotal = total;
      best = (model: pair.key, entry: entry);
    }
  }
  return best;
}
