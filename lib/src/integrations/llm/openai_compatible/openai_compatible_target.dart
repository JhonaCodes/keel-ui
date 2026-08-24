/// Transporte OpenAI-compatible por API HTTP.
///
/// [baseUrl] es la raíz compatible del proveedor, por ejemplo:
/// - OpenRouter: `https://openrouter.ai/api/v1`
/// - DeepSeek: `https://api.deepseek.com`
/// - MiniMax: `https://api.minimax.io/v1`
///
/// [secretRef] es el nombre del secret en la bóveda local, nunca el valor.
final class OpenAiCompatibleApi {
  final String baseUrl;
  final String secretRef;

  const OpenAiCompatibleApi({required this.baseUrl, required this.secretRef});
}
