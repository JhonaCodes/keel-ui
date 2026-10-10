part of '../keel_api.dart';

/// The HTTP client of keel-api, on `package:http`.
///
/// It is the boundary where throwing stops: every method answers
/// `Result<T, KeelApiFailure>`. A signed request carries the session's
/// bearer token; a 401 renews it once through the [AccessTokenSource] and
/// repeats the request. Redirects are never followed, so the token is never
/// carried to another address.
///
/// Log lines name the method, the path and the status — never a header, a
/// body or a token.
class KeelApiClient {
  KeelApiClient();

  /// How long one request may take before it counts as a network failure.
  static const Duration timeout = Duration(seconds: 30);

  http.Client _http = http.Client();
  String _origin = '';
  AccessTokenSource? _tokens;

  /// Lets a test answer the requests itself (`package:http/testing.dart`).
  @visibleForTesting
  void useHttpClient(http.Client client) => _http = client;

  /// The server this client points at, `https://<host>`; empty when none.
  String get origin => _origin;

  /// Points the client at [origin]; signed requests ask [tokens] for the
  /// session's token.
  void point(String origin, {AccessTokenSource? tokens}) {
    _origin = normalizeOrigin(origin);
    _tokens = tokens;
    Log.d('keel_api: pointing at ${Uri.tryParse(_origin)?.host ?? '-'}');
  }

  /// Points nowhere: every call answers [KeelApiFailureKind.notSignedIn].
  void detach() {
    _origin = '';
    _tokens = null;
  }

  /// [origin] trimmed and without a trailing slash, so joining a path never
  /// doubles it.
  static String normalizeOrigin(String origin) {
    final trimmed = origin.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// A JSON object answer.
  Future<Result<Map<String, dynamic>, KeelApiFailure>> getObject(
    String path, {
    Map<String, Object?>? query,
  }) async => (await send('GET', path, query: query)).flatMap(_asObject);

  /// A JSON array answer, narrowed to its objects.
  Future<Result<List<Map<String, dynamic>>, KeelApiFailure>> getList(
    String path, {
    Map<String, Object?>? query,
  }) async => (await send('GET', path, query: query)).flatMap(_asList);

  Future<Result<Map<String, dynamic>, KeelApiFailure>> postObject(
    String path, {
    Object? body,
    bool signed = true,
  }) async =>
      (await send('POST', path, body: body, signed: signed)).flatMap(_asObject);

  Future<Result<Map<String, dynamic>, KeelApiFailure>> deleteObject(
    String path,
  ) async => (await send('DELETE', path)).flatMap(_asObject);

  /// Sends one request and reads its answer. [signed] requests go with the
  /// session's token and fail with [KeelApiFailureKind.notSignedIn] when
  /// there is none; sign-in and refresh go unsigned.
  Future<Result<Object?, KeelApiFailure>> send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool signed = true,
  }) async {
    if (_origin.isEmpty) return Err(_notSignedIn);
    final uri = _uri(path, query);
    if (!signed) {
      final answer = await _attempt(method, uri, body, null);
      return answer.flatMap((response) => _interpret(response, method, path));
    }

    final tokens = _tokens;
    final token = await tokens?.accessToken();
    if (tokens == null || token == null) return Err(_notSignedIn);
    var answer = await _attempt(method, uri, body, token);
    // An expired access token answers 401 (`token_expired`): renew once and
    // repeat. A second 401 is the answer — the session is over.
    if (answer case Ok(data: final response) when response.statusCode == 401) {
      final renewed = await tokens.renew();
      if (renewed != null) answer = await _attempt(method, uri, body, renewed);
    }
    return answer.flatMap((response) => _interpret(response, method, path));
  }

  Uri _uri(String path, Map<String, Object?>? query) {
    final uri = Uri.parse('$_origin$path');
    final cleaned = <String, String>{
      for (final MapEntry(:key, :value) in (query ?? const {}).entries)
        if (value != null && '$value'.isNotEmpty) key: '$value',
    };
    return cleaned.isEmpty ? uri : uri.replace(queryParameters: cleaned);
  }

  /// One request on the wire; the answer whatever its status, or why there
  /// was none.
  Future<Result<http.Response, KeelApiFailure>> _attempt(
    String method,
    Uri uri,
    Object? body,
    String? token,
  ) async {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return Ok(await http.Response.fromStream(streamed).timeout(timeout));
    } on TimeoutException {
      Log.w('keel_api: $method ${uri.path} timed out');
      return Err(const KeelApiFailure(kind: KeelApiFailureKind.network));
    } on SocketException catch (error) {
      Log.w('keel_api: $method ${uri.path} failed: ${error.message}');
      return Err(const KeelApiFailure(kind: KeelApiFailureKind.network));
    } on TlsException catch (error) {
      Log.w('keel_api: $method ${uri.path} failed TLS: ${error.message}');
      return Err(const KeelApiFailure(kind: KeelApiFailureKind.network));
    } on http.ClientException catch (error) {
      Log.w('keel_api: $method ${uri.path} failed: ${error.message}');
      return Err(const KeelApiFailure(kind: KeelApiFailureKind.network));
    }
  }

  Result<Object?, KeelApiFailure> _interpret(
    http.Response response,
    String method,
    String path,
  ) {
    final status = response.statusCode;
    final text = response.body.trim();
    Object? decoded;
    var readable = true;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        readable = false;
      }
    }

    if (status >= 200 && status < 300) {
      return readable
          ? Ok(decoded)
          : Err(
              KeelApiFailure(
                kind: KeelApiFailureKind.unexpected,
                statusCode: status,
              ),
            );
    }

    Log.w('keel_api: $method $path answered $status');
    return Err(
      KeelApiFailure(
        kind: _kindFor(status),
        serverMessage: switch (decoded) {
          final Map<String, dynamic> object => KeelJson.decodeText(
            object['error'],
          ),
          _ => null,
        },
        statusCode: status,
        retryAfterSeconds: KeelJson.decodeInt(response.headers['retry-after']),
      ),
    );
  }

  static KeelApiFailureKind _kindFor(int status) => switch (status) {
    400 || 422 => KeelApiFailureKind.badRequest,
    401 => KeelApiFailureKind.unauthorized,
    403 => KeelApiFailureKind.forbidden,
    404 => KeelApiFailureKind.notFound,
    409 => KeelApiFailureKind.conflict,
    429 => KeelApiFailureKind.rateLimited,
    >= 500 => KeelApiFailureKind.server,
    _ => KeelApiFailureKind.unexpected,
  };

  static Result<Map<String, dynamic>, KeelApiFailure> _asObject(Object? data) =>
      switch (data) {
        final Map<String, dynamic> object => Ok(object),
        _ => Err(const KeelApiFailure(kind: KeelApiFailureKind.unexpected)),
      };

  static Result<List<Map<String, dynamic>>, KeelApiFailure> _asList(
    Object? data,
  ) => switch (data) {
    final List<Object?> rows => Ok(
      rows.whereType<Map<String, dynamic>>().toList(growable: false),
    ),
    _ => Err(const KeelApiFailure(kind: KeelApiFailureKind.unexpected)),
  };

  static const KeelApiFailure _notSignedIn = KeelApiFailure(
    kind: KeelApiFailureKind.notSignedIn,
  );
}
