/// Product attribution sent to gateways that publish an app directory. It
/// identifies Keel, never the user: no account, no workspace, no prompt.
const kKeelProductUrl = 'https://github.com/JhonaCodes/keel-ui';
const kKeelProductName = 'Keel';

/// En qué se diferencian entre sí los proveedores que hablan el dialecto de
/// OpenAI. Es un dato del target —algo que el proveedor sabe de sí mismo— y no
/// una inspección de la URL adentro del runner: un `baseUrl.contains(...)` es
/// el catch-all encubierto que invariantes-llm-providers prohíbe.
///
/// La diferencia importa porque **mandar la forma equivocada no da error**: el
/// proveedor ignora el campo en silencio y el turno corre sin razonar.
enum OpenAiCompatibleDialect {
  /// OpenAI, DeepSeek, MiniMax…: el esfuerzo va PLANO en la raíz del body,
  /// `"reasoning_effort": "low"`, y no hay cabeceras de atribución.
  plain,

  /// OpenRouter: el esfuerzo va ANIDADO, `"reasoning": {"effort": "low"}`, y
  /// el gateway además publica las cabeceras de atribución de la app.
  openRouter;

  /// El fragmento de body que pide razonamiento, o vacío cuando no hay nada
  /// que pedir. Un [effort] nulo o vacío omite el campo ENTERO: mandar un
  /// valor que el proveedor no conoce es basura que igual se ignora.
  Map<String, dynamic> reasoningEffortField(String? effort) {
    if (effort == null || effort.isEmpty) return const {};
    return switch (this) {
      OpenAiCompatibleDialect.plain => {'reasoning_effort': effort},
      OpenAiCompatibleDialect.openRouter => {
        'reasoning': {'effort': effort},
      },
    };
  }

  /// Cabeceras de ATRIBUCIÓN, no de autenticación: no llevan ningún dato del
  /// usuario. Solo OpenRouter las usa; al resto son ruido.
  Map<String, String> get attributionHeaders => switch (this) {
    OpenAiCompatibleDialect.plain => const {},
    OpenAiCompatibleDialect.openRouter => const {
      'http-referer': kKeelProductUrl,
      'x-title': kKeelProductName,
    },
  };
}

/// Transporte OpenAI-compatible por API HTTP.
///
/// [baseUrl] es la raíz compatible del proveedor, por ejemplo:
/// - OpenRouter: `https://openrouter.ai/api/v1`
/// - DeepSeek: `https://api.deepseek.com`
/// - MiniMax: `https://api.minimax.io/v1`
///
/// [secretRef] es el nombre del secret en la bóveda local, nunca el valor.
///
/// [dialect] es obligatorio a propósito: un proveedor nuevo que no declara el
/// suyo no compila, en vez de heredar un default silencioso y salir a la red
/// con la forma equivocada.
final class OpenAiCompatibleApi {
  final String baseUrl;
  final String secretRef;
  final OpenAiCompatibleDialect dialect;

  const OpenAiCompatibleApi({
    required this.baseUrl,
    required this.secretRef,
    required this.dialect,
  });
}
