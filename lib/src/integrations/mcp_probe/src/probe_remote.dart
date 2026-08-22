part of '../mcp_probe.dart';

/// Habla JSON-RPC contra un servidor remoto por HTTP.
///
/// `dart_mcp` trae el canal de stdio pero no uno de HTTP, así que el
/// apretón de manos va a mano. Son tres mensajes y el protocolo está
/// publicado; escribirlos acá es más barato que arrastrar otra dependencia.
///
/// Un servidor declarado como SSE se prueba igual: muchos de los que
/// publican una URL `/sse` ya contestan el transporte nuevo. Si rechaza el
/// POST, se dice tal cual en vez de inventar un diagnóstico.
Future<McpProbeResult> _probeRemote(
  McpServerConfig config,
  Map<String, String> secretValues,
) async {
  final headers = <String, String>{
    for (final entry in config.headers.entries)
      entry.key: ?resolveSecretPlaceholders(entry.value, secretValues),
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream',
  };

  final client = http.Client();
  try {
    final uri = Uri.parse(config.url);

    final initialize = await client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': ProtocolVersion.latestSupported.versionString,
          'capabilities': <String, Object?>{},
          'clientInfo': {'name': 'keel-ui', 'version': '1.0.0'},
        },
      }),
    );

    if (initialize.statusCode >= 400) {
      return McpProbeResult.failed(_httpError(initialize, config.transport));
    }

    // El servidor puede abrir una sesión y exigir su id en todo lo que
    // siga. Los que no lo hacen simplemente no mandan el header.
    final sessionId = initialize.headers['mcp-session-id'];
    if (sessionId != null) headers['Mcp-Session-Id'] = sessionId;

    final handshake = _decodeRpc(initialize.body);
    if (handshake == null) {
      return McpProbeResult.failed(
        'Contestó ${initialize.statusCode} pero no en JSON-RPC. Puede que la '
        'URL apunte a otra cosa.',
      );
    }
    if (handshake['error'] case final Map<String, dynamic> error) {
      return McpProbeResult.failed(_rpcError(error));
    }

    await client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }),
    );

    final listed = await client.post(
      uri,
      headers: headers,
      body: jsonEncode({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'}),
    );
    if (listed.statusCode >= 400) {
      return McpProbeResult.failed(_httpError(listed, config.transport));
    }

    final payload = _decodeRpc(listed.body);
    if (payload?['error'] case final Map<String, dynamic> error) {
      return McpProbeResult.failed(_rpcError(error));
    }

    final info = handshake['result']?['serverInfo'] as Map<String, dynamic>?;
    final tools = payload?['result']?['tools'] as List? ?? const [];
    return McpProbeResult(
      ok: true,
      at: DateTime.now(),
      serverName: info?['name'] as String? ?? '',
      serverVersion: info?['version'] as String? ?? '',
      tools: [
        for (final tool in tools)
          if (tool case {'name': final String name}) name,
      ],
    );
  } finally {
    client.close();
  }
}

/// Un cuerpo que puede venir como JSON pelado o como un stream de eventos.
/// En el segundo caso el mensaje viaja en las líneas `data:`, y el que
/// importa es el último.
Map<String, dynamic>? _decodeRpc(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('{')) {
    final decoded = jsonDecode(trimmed);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Map<String, dynamic>? last;
  for (final line in const LineSplitter().convert(trimmed)) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trim();
    if (payload.isEmpty || !payload.startsWith('{')) continue;
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) last = decoded;
  }
  return last;
}

/// El código HTTP, traducido a lo que hay que hacer al respecto.
String _httpError(http.Response response, McpTransport transport) =>
    switch (response.statusCode) {
      401 =>
        '401 · el servidor contestó pero rechazó la credencial. Si es de '
            'los que piden OAuth, Keel solo sabe mandar un token en el header: '
            'buscá uno de API en su configuración.',
      403 => '403 · la credencial es válida pero no alcanza para esto.',
      404 => '404 · esa URL no existe. Revisá la ruta contra su documentación.',
      405 when transport == McpTransport.sse =>
        '405 · pide una conexión SSE de las viejas. Keel se lo puede entregar '
            'igual al CLI, pero desde acá no se pueden listar sus tools.',
      405 => '405 · no acepta POST en esa URL.',
      429 => '429 · te está limitando. Probá en un rato.',
      _ => '${response.statusCode} · ${_firstLine(response.body)}',
    };

String _rpcError(Map<String, dynamic> error) {
  final message = error['message'] as String? ?? 'error sin mensaje';
  final code = error['code'];
  return code == null ? message : '$message (código $code)';
}

String _firstLine(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'sin cuerpo';
  final line = const LineSplitter().convert(trimmed).first;
  return line.length > 160 ? '${line.substring(0, 160)}…' : line;
}
