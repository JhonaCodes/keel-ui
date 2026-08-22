/// Lo que un servidor MCP externo contestó cuando se le preguntó qué tiene.
///
/// Vive en el módulo y no en la integración que lo produce porque es un
/// modelo: lo guarda un repositorio, lo lleva el estado y lo dibuja la UI.
/// La integración `mcp_probe` es la que sabe cómo conseguirlo.
library;

/// Lo que contestó un servidor MCP cuando se le preguntó.
class McpProbeResult {
  final bool ok;

  /// Cómo se llama a sí mismo el servidor, y su versión. Sirve para darse
  /// cuenta de que se está hablando con otra cosa de la que se creía.
  final String serverName;
  final String serverVersion;

  /// Los nombres de las tools que expone, en el orden en que las declaró.
  final List<String> tools;

  /// Vacío cuando [ok]. Es texto para leer, no un código.
  final String error;

  final Duration elapsed;
  final DateTime at;

  const McpProbeResult({
    required this.ok,
    required this.at,
    this.serverName = '',
    this.serverVersion = '',
    this.tools = const [],
    this.error = '',
    this.elapsed = Duration.zero,
  });

  McpProbeResult.failed(String message)
    : ok = false,
      serverName = '',
      serverVersion = '',
      tools = const [],
      error = message,
      elapsed = Duration.zero,
      at = DateTime.now();

  McpProbeResult withElapsed(Duration value) => McpProbeResult(
    ok: ok,
    at: at,
    serverName: serverName,
    serverVersion: serverVersion,
    tools: tools,
    error: error,
    elapsed: value,
  );

  /// Cómo se resume en una línea, que es como lo muestra la tarjeta.
  String get summary {
    if (!ok) return error;
    final name = serverName.isEmpty ? 'Conectó' : 'Conectó · $serverName';
    final version = serverVersion.isEmpty ? '' : ' $serverVersion';
    return '$name$version · ${tools.length} tools';
  }

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'serverName': serverName,
    'serverVersion': serverVersion,
    'tools': tools,
    'error': error,
    'elapsedMs': elapsed.inMilliseconds,
    'at': at.toIso8601String(),
  };

  factory McpProbeResult.fromJson(Map<String, dynamic> json) => McpProbeResult(
    ok: json['ok'] as bool? ?? false,
    serverName: json['serverName'] as String? ?? '',
    serverVersion: json['serverVersion'] as String? ?? '',
    tools: (json['tools'] as List?)?.cast<String>() ?? const [],
    error: json['error'] as String? ?? '',
    elapsed: Duration(milliseconds: json['elapsedMs'] as int? ?? 0),
    at: DateTime.parse(json['at'] as String),
  );
}
