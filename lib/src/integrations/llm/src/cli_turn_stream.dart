import 'dart:async';
import 'dart:convert';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';

/// La salida de un CLI traducida al contrato de eventos, con el fallback de
/// código de salida al final.
///
/// Por qué existe como pieza aparte: los dos runners de CLI hacían lo mismo
/// —leer líneas, decodificar, delegar en su reader, y al cerrar mirar el
/// código de salida— y los dos convertían un tope de turnos en una falla de
/// proveedor. El tope sale con código distinto de cero DESPUÉS de haber dicho
/// en el stream cómo terminó, así que el `failure` del código duplicaba una
/// causa que ya estaba contada.
///
/// [read] es el reader del proveedor ([ClaudeStreamReader.read],
/// [CodexStreamReader.read]): un evento crudo entra, cero o más eventos del
/// contrato salen.
Stream<LlmEvent> cliTurnEvents({
  required Stream<String> lines,
  required Iterable<LlmEvent> Function(Map<String, dynamic> event) read,
  required Future<String> stderr,
  required Future<int> exitCode,
  required String provider,
  bool Function() isCancelled = _never,
}) async* {
  // Si el stream ya dijo cómo terminó el turno, el código de salida no
  // agrega una causa: la repite. El fallback queda para el crash real, el
  // que se muere sin llegar a decir nada.
  var reportedTurn = false;
  // Lo último que dijo el proceso antes de morir: la única pista que queda
  // cuando stderr vino vacío. Ver el `Log.e` del final.
  var lastLine = '';

  await for (final line in lines) {
    if (isCancelled()) break;
    if (line.trim().isEmpty) continue;
    lastLine = line.length > 500 ? '${line.substring(0, 500)}…' : line;

    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      Log.w('Unparseable $provider output line: $line');
      continue;
    }

    for (final message in read(event)) {
      // Acotado a propósito: un `result` de error también emite
      // `turnCompleted`, pero solo el tope trae su causa completa in-band.
      // Un `error_during_execution` dice QUE falló y deja el PORQUÉ en
      // stderr, así que ahí el fallback sigue siendo la única causa que hay.
      if (message['type'] == 'turnCompleted' &&
          (message['isError'] != true ||
              message['stopReason'] == 'error_max_turns')) {
        reportedTurn = true;
      }
      yield message;
    }
  }

  final stderrText = (await stderr).trim();
  if (isCancelled()) return;

  final code = await exitCode;
  if (code == 0 || reportedTurn) return;

  // Un fallo que llega hasta acá se murió sin decir cómo, y hasta ahora no
  // dejaba rastro en ningún lado: el diagnóstico había que sacarlo del
  // `.jsonl` del propio CLI. SEVERE porque es el nivel que engancha el
  // fault journal; la última línea de stdout suele traer la causa cuando
  // stderr vino vacío.
  Log.e(
    '$provider terminó con código $code sin reportar el turno. '
    'stderr: ${stderrText.isEmpty ? '(vacío)' : stderrText} | '
    'última línea de stdout: ${lastLine.isEmpty ? '(ninguna)' : lastLine}',
  );

  yield {
    'type': 'failure',
    'message': stderrText.isEmpty
        ? '$provider terminó con código $code'
        : stderrText,
  };
}

bool _never() => false;
