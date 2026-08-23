part of '../fault_journal.dart';

bool _installed = false;

/// Deja la app anotando todo lo que se rompa. Se llama una sola vez, en
/// `main`, y solo en la ventana principal: las sub-ventanas son otro engine
/// sin base donde escribir.
///
/// Ninguna de las tres fuentes reemplaza lo que ya hacía la app. La consola
/// sigue imprimiendo igual —con el formato de `logger_rs` y con el cartel
/// rojo de Flutter— porque la consola sirve mientras estás mirándola, y el
/// diario sirve para todo el resto del tiempo.
void installFaultCapture() {
  if (_installed) return;
  _installed = true;

  // ── 1. las cuarenta y pico de llamadas a Log.e que ya existen ────────
  //
  // Engancharse acá y no en cada archivo es la diferencia entre una
  // funcionalidad y una campaña: `logger_rs` publica en `Logger.root`, así
  // que toda llamada a `Log.e` —incluidas las que se escriban mañana, y las
  // de los paquetes de terceros— pasa por este listener sin que nadie tenga
  // que acordarse de nada.
  Logger.root.onRecord.listen((record) {
    if (record.level < Level.SEVERE) return;
    // El stack casi nunca viene: la mayoría de las llamadas pasan `error:`
    // y nada más. Un `Error` trae el suyo propio y con eso alcanza para
    // saber de qué archivo salió.
    final error = record.error;
    final stack =
        record.stackTrace ?? (error is Error ? error.stackTrace : null);
    _record(
      message: error == null ? record.message : '${record.message}: $error',
      where: faultOriginOf(stack),
      // `Log.f` publica en SHOUT y `Log.e` en SEVERE: la severidad ya venía
      // dicha en la llamada, solo faltaba no tirarla.
      severity: record.level >= Level.SHOUT
          ? FaultSeverity.critica
          : FaultSeverity.error,
      detail: [
        record.message,
        if (error != null) '$error',
        if (stack != null) '$stack',
      ].join('\n'),
    );
  });

  // ── 2. lo que revienta dibujando ─────────────────────────────────────
  //
  // Se encadena con el handler anterior en vez de reemplazarlo: el que
  // estaba es el que imprime el cartel rojo en la consola y el que pinta el
  // recuadro gris en pantalla.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    _record(
      message: details.exceptionAsString(),
      where: faultOriginOf(details.stack),
      context: details.context?.toDescription() ?? '',
      severity: FaultSeverity.interfaz,
      detail: [
        details.exceptionAsString(),
        if (details.stack != null) '${details.stack}',
      ].join('\n'),
    );
  };

  // ── 3. lo que revienta lejos de todo ─────────────────────────────────
  //
  // Una excepción asíncrona sin `await` que la agarre no pasa por ninguno
  // de los dos anteriores: termina en el handler de la plataforma, que sin
  // esto solo la imprime. Se la manda por `Log.e` a propósito, para que
  // salga por el mismo lugar que el resto y entre por la puerta 1.
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.e('Excepción sin dueño', error: error, stackTrace: stack);
    return true;
  };
}

/// El archivo de Keel más cercano al lugar donde reventó: `sesión.dart:184`.
///
/// Se saltean los frames de este mismo diario —si no, todas las fallas
/// dirían que salieron de acá— y los de los paquetes, que dicen dónde se
/// notó el problema y no dónde está.
String faultOriginOf(StackTrace? stack) {
  if (stack == null) return '';
  for (final line in stack.toString().split('\n')) {
    if (!line.contains('package:keel_ui/')) continue;
    if (line.contains('fault_journal')) continue;
    final match = _framePattern.firstMatch(line);
    if (match != null) return match.group(1)!;
  }
  return '';
}

/// `…/algo.dart:12:34` → `algo.dart:12`. La columna no le dice nada a nadie.
final _framePattern = RegExp(r'([a-z_0-9]+\.dart:\d+)');

/// El puente entre las tres fuentes y el ViewModel.
///
/// No espera y no puede tirar: la reentrancia y las escrituras que fallan
/// las resuelve [FaultJournalViewModel.record], que es el que sabe si lo que
/// llegó es lo mismo de recién y si la base todavía contesta.
void _record({
  required String message,
  String where = '',
  String detail = '',
  String context = '',
  FaultSeverity severity = FaultSeverity.error,
}) {
  unawaited(
    FaultJournalService.instance.notifier.record(
      message: message,
      where: where,
      detail: detail,
      context: context,
      severity: severity,
    ),
  );
}
