part of '../catalog_bridge_core.dart';

/// Lo que se le contesta al cliente cuando del otro lado no hay nadie.
///
/// Es un texto y no un código a secas porque el único que lo va a leer es
/// una persona mirando por qué su cliente MCP dice "falló": tiene que decir
/// qué hacer, no qué pasó.
const _kKeelClosedMessage =
    'Keel is not running. Open the Keel desktop app and reconnect this MCP '
    'server.';

/// El relay: MCP por stdio de un lado, el catálogo de la app corriendo del
/// otro.
///
/// Un mensaje entra por el canal, sale tal cual por un POST al host, y la
/// respuesta del host vuelve tal cual por el canal. No se interpreta el
/// contenido más allá del `id` —que es lo único que decide si hay que
/// contestar— justamente para que agregar una tool al catálogo no obligue a
/// tocar nada acá.
abstract final class CatalogMcpBridge {
  /// Lee mensajes JSON-RPC de [input] y escribe las respuestas en [output],
  /// uno por línea, hasta que el cliente cierre el canal.
  ///
  /// Los mensajes se atienden de a uno, en orden. Es a propósito: el
  /// transporte stdio de MCP no tiene multiplexado, y el host crea una
  /// instancia por request, así que paralelizar acá no compraría nada y
  /// haría que `initialize` pudiera terminar después de `tools/list`.
  static Future<void> serve({
    required String endpointPath,
    Stream<List<int>>? input,
    StreamSink<List<int>>? output,
  }) async {
    final channel = stdioChannel(
      input: input ?? stdin,
      output: output ?? stdout,
    );
    final client = HttpClient();
    try {
      await for (final message in channel.stream) {
        final reply = await _relay(message, endpointPath, client);
        if (reply != null) channel.sink.add(reply);
      }
    } finally {
      client.close(force: true);
      await channel.sink.close();
    }
  }

  /// Manda [message] al host y devuelve lo que haya que escribir en el
  /// canal, o null cuando no hay que escribir nada.
  ///
  /// Null es el caso normal de una notificación (sin `id`): el protocolo no
  /// espera respuesta y el host contesta 202 sin cuerpo. Contestarle algo
  /// sería un error de protocolo, no una cortesía.
  static Future<String?> _relay(
    String message,
    String endpointPath,
    HttpClient client,
  ) async {
    final Object? id;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return null;
      id = decoded['id'];
    } on FormatException {
      // Basura en el canal: no hay `id` al que contestarle, y un error sin
      // `id` no es un mensaje JSON-RPC válido. Se descarta.
      return null;
    }

    final endpoint = await CatalogEndpointFile.read(endpointPath);
    if (endpoint == null) return _errorFor(id, _kKeelClosedMessage);

    try {
      final request = await client.postUrl(endpoint.uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${endpoint.token}',
      );
      request.headers.contentType = ContentType.json;
      request.write(message);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (id == null) return null;
      if (response.statusCode != HttpStatus.ok || body.isEmpty) {
        // Un 401 acá es el enganche viejo de un arranque anterior cuyo
        // puerto reusó otro proceso; un 404, un host que ya no sirve el
        // catálogo. Para quien mira, los dos son "reconectá".
        return _errorFor(
          id,
          'The Keel catalog answered ${response.statusCode}. '
          '$_kKeelClosedMessage',
        );
      }
      return body;
    } on SocketException {
      // El caso más común y menos excepcional de todos: el archivo de
      // enganche quedó de la sesión anterior y Keel ya se cerró.
      return _errorFor(id, _kKeelClosedMessage);
    } on HttpException catch (error) {
      return _errorFor(id, 'The Keel catalog connection failed: $error');
    }
  }

  /// Un error de JSON-RPC bien formado, o null si el mensaje no tenía `id`
  /// y por lo tanto no admite respuesta.
  static String? _errorFor(Object? id, String message) {
    if (id == null) return null;
    return jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': -32000, 'message': message},
    });
  }
}
