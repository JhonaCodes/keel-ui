part of '../genui.dart';

/// Cuánto se espera un pedido antes de darlo por perdido.
const kBoardHttpTimeout = Duration(seconds: 30);

/// Cuánto se espera un comando. Más largo que el HTTP porque acá entra un
/// `gcloud` que renueva credenciales o un `adb` esperando al teléfono.
const kBoardCommandTimeout = Duration(seconds: 60);

/// Corre los pasos de [action] en orden y devuelve cómo fue.
///
/// Se corta en el primero que falla, y eso es deliberado: el paso 2 casi
/// siempre usa lo que capturó el paso 1, así que seguir sería disparar un
/// pedido con un token vacío contra tu API. Mejor un error corto que una
/// consecuencia larga.
///
/// [values] llega con los campos del tablero YA resueltos, secrets incluidos.
/// Esta función no sabe qué es un secret, y no tiene por qué: lo único que
/// hace es no escribir en ningún lado lo que le pasaron.
Future<BoardRun> runBoardAction({
  required Board board,
  required BoardAction action,
  required Map<String, String> values,
  http.Client? client,
  DateTime? now,
}) async {
  final results = <BoardStepResult>[];
  final scope = <String, String>{...values};
  final ownsClient = client == null;
  final http.Client httpClient = client ?? http.Client();

  try {
    for (final step in action.steps) {
      final result = switch (step.kind) {
        BoardStepKind.http => await _runHttpStep(step, scope, httpClient),
        BoardStepKind.comando => await _runCommandStep(step, scope),
      };
      results.add(result);
      if (!result.ok) break;
      scope.addAll(result.captured);
    }
  } finally {
    if (ownsClient) httpClient.close();
  }

  return BoardRun(
    id: generateUuidV4(),
    boardId: board.id,
    actionId: action.id,
    actionLabel: action.label,
    at: now ?? DateTime.now(),
    steps: results,
  );
}

Future<BoardStepResult> _runHttpStep(
  BoardStep step,
  Map<String, String> scope,
  http.Client client,
) async {
  final StepRequest request;
  try {
    request = buildStepRequest(step, scope);
  } on MissingTemplateKeys catch (error) {
    return BoardStepResult(
      kind: step.kind,
      preview: step.preview,
      ok: false,
      error: error.message,
    );
  } on FormatException catch (error) {
    return BoardStepResult(
      kind: step.kind,
      preview: step.preview,
      ok: false,
      error: error.message,
    );
  }

  final preview = '${request.method} ${request.uri}';
  final started = DateTime.now();
  try {
    final outgoing = http.Request(request.method, request.uri)
      ..headers.addAll(request.headers);
    if (request.body.isNotEmpty) {
      // El content-type va ANTES del cuerpo: el setter de `body` pone
      // `text/plain` cuando no encuentra uno, y después ya es tarde. Un
      // JSON mandado como texto plano lo rechaza media internet sin decir
      // por qué.
      final declarado = request.headers.keys.any(
        (key) => key.toLowerCase() == 'content-type',
      );
      if (!declarado) {
        outgoing.headers['content-type'] = _looksLikeJson(request.body)
            ? 'application/json; charset=utf-8'
            : 'text/plain; charset=utf-8';
      }
      outgoing.body = request.body;
    }

    final streamed = await client.send(outgoing).timeout(kBoardHttpTimeout);
    final response = await http.Response.fromStream(streamed);
    final elapsed = DateTime.now().difference(started);
    final ok = response.statusCode < 400;

    return BoardStepResult(
      kind: step.kind,
      preview: preview,
      ok: ok,
      status: response.statusCode,
      elapsed: elapsed,
      output: response.body,
      error: ok ? '' : response.body,
      headers: response.headers,
      captured: ok ? _captureFromHttp(step, response) : const {},
    );
  } on TimeoutException {
    return BoardStepResult(
      kind: step.kind,
      preview: preview,
      ok: false,
      elapsed: DateTime.now().difference(started),
      error: 'No contestó en ${kBoardHttpTimeout.inSeconds} segundos.',
    );
  } on SocketException catch (error) {
    return BoardStepResult(
      kind: step.kind,
      preview: preview,
      ok: false,
      elapsed: DateTime.now().difference(started),
      error: 'No se pudo conectar: ${error.message}',
    );
  }
}

Future<BoardStepResult> _runCommandStep(
  BoardStep step,
  Map<String, String> scope,
) async {
  final StepCommand command;
  try {
    command = buildStepCommand(step, scope);
  } on MissingTemplateKeys catch (error) {
    return BoardStepResult(
      kind: step.kind,
      preview: step.preview,
      ok: false,
      error: error.message,
    );
  }

  final preview = '${command.command} ${command.args.join(' ')}'.trim();
  final started = DateTime.now();
  try {
    final result = await Process.run(
      command.command,
      command.args,
      runInShell: true,
    ).timeout(kBoardCommandTimeout);

    final stdoutText = '${result.stdout}';
    final stderrText = '${result.stderr}';
    final ok = result.exitCode == 0;

    return BoardStepResult(
      kind: step.kind,
      preview: preview,
      ok: ok,
      status: result.exitCode,
      elapsed: DateTime.now().difference(started),
      output: stdoutText,
      // Un comando que anduvo igual puede haber escrito en stderr; guardarlo
      // sin marcarlo como error es la diferencia entre un aviso y una falla.
      error: ok ? '' : (stderrText.trim().isEmpty ? stdoutText : stderrText),
      captured: ok ? _captureFromCommand(step, stdoutText) : const {},
    );
  } on TimeoutException {
    return BoardStepResult(
      kind: step.kind,
      preview: preview,
      ok: false,
      elapsed: DateTime.now().difference(started),
      error: 'No terminó en ${kBoardCommandTimeout.inSeconds} segundos.',
    );
  } on ProcessException catch (error) {
    return BoardStepResult(
      kind: step.kind,
      preview: preview,
      ok: false,
      elapsed: DateTime.now().difference(started),
      error:
          'No se pudo ejecutar "${error.executable}". ¿Está instalado en '
          'esta máquina?',
    );
  }
}

Map<String, String> _captureFromHttp(BoardStep step, http.Response response) {
  if (step.captures.isEmpty) return const {};

  Object? decoded;
  var attempted = false;

  final captured = <String, String>{};
  for (final capture in step.captures) {
    final value = switch (capture.from) {
      CaptureFrom.salida => response.body.trim(),
      CaptureFrom.header => response.headers[capture.path.toLowerCase()],
      CaptureFrom.json => () {
        if (!attempted) {
          attempted = true;
          try {
            decoded = jsonDecode(response.body);
          } on FormatException {
            decoded = null;
          }
        }
        return readJsonPath(decoded, capture.path);
      }(),
    };
    if (value != null) captured[capture.as] = value;
  }
  return captured;
}

Map<String, String> _captureFromCommand(BoardStep step, String stdoutText) {
  if (step.captures.isEmpty) return const {};

  final captured = <String, String>{};
  for (final capture in step.captures) {
    final value = switch (capture.from) {
      CaptureFrom.salida => stdoutText.trim(),
      CaptureFrom.json => () {
        try {
          return readJsonPath(jsonDecode(stdoutText), capture.path);
        } on FormatException {
          return null;
        }
      }(),
      // Un comando no tiene headers. Se ignora en vez de inventar un valor.
      CaptureFrom.header => null,
    };
    if (value != null) captured[capture.as] = value;
  }
  return captured;
}

bool _looksLikeJson(String body) {
  final trimmed = body.trimLeft();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}
