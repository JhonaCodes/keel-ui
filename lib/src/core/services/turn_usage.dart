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
///
/// [turnModel] es el modelo con el que arrancó el turno, tal como lo informa
/// el evento `system/init`. Importa para el TECHO de contexto: `modelUsage`
/// trae una entrada por modelo que participó —incluidos los submodelos de un
/// subagente— y elegir por volumen de tokens puede quedarse con la ventana
/// del chico. Una traza real de este repo tenía `haiku@200k` junto a
/// `sonnet@1M`: tomar la de 200k hace que el anillo se sature con la quinta
/// parte del contexto.
TurnUsage readTurnUsage(Map<String, dynamic> event, {String turnModel = ''}) {
  final usage = event['usage'] as Map<String, dynamic>?;
  final modelUsage = event['modelUsage'] as Map<String, dynamic>?;
  final main =
      _namedModelUsage(modelUsage, turnModel) ?? _mainModelUsage(modelUsage);

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

/// La entrada de `modelUsage` que corresponde al modelo del turno.
///
/// El CLI nombra las claves con el id completo, que no siempre es igual al
/// alias con el que se pidió el turno, así que se acepta que una contenga a
/// la otra en cualquier dirección.
({String model, Map<String, dynamic> entry})? _namedModelUsage(
  Map<String, dynamic>? modelUsage,
  String turnModel,
) {
  if (modelUsage == null || turnModel.isEmpty) return null;
  for (final pair in modelUsage.entries) {
    if (pair.key == turnModel ||
        pair.key.contains(turnModel) ||
        turnModel.contains(pair.key)) {
      return (model: pair.key, entry: pair.value as Map<String, dynamic>);
    }
  }
  return null;
}

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
