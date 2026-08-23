part of '../fault_journal.dart';

/// Cuánto se espera entre dos avisos del sistema. Una falla suele venir con
/// tres amigas; tres globos apilados no informan más que uno.
const _kNoticeGap = Duration(minutes: 2);

/// Cuánto se le da al aviso antes de dejarlo ir.
const _kNoticeBudget = Duration(seconds: 5);

DateTime? _noticedAt;

/// Avisa por fuera de Keel que algo se rompió — **solo si no estás mirando
/// Keel**.
///
/// Con la ventana enfocada alcanza el punto rojo del rail: ya estás acá y un
/// globo encima es una interrupción de algo que podés ver girando la vista.
/// Lo que el punto rojo no puede hacer es avisarte mientras el flujo corre
/// veinte minutos y vos estás en otra cosa, que es justo cuando una falla se
/// pierde.
///
/// Sale por `osascript` y no por un paquete nuevo: la app ya habla con macOS
/// así —`which`, `sysctl`, `ps`— y una dependencia más para tres líneas de
/// AppleScript es una dependencia más para mantener. El costo es que macOS
/// atribuye el globo al Editor de Scripts, y si nunca le diste permiso de
/// notificar, no aparece. Por eso el punto rojo es el aviso de verdad y esto
/// es el extra.
Future<void> noticeOf(Fault fault) async {
  if (!Platform.isMacOS) return;
  // En una corrida de tests, no. `flutter test` no es alguien mirando la
  // pantalla, y `osascript` levantando globos de verdad —o esperando un
  // permiso que nadie va a dar— cuelga la corrida entera. Comprobado.
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;

  final last = _noticedAt;
  if (last != null && DateTime.now().difference(last) < _kNoticeGap) return;

  // Si no se puede saber si la ventana está enfocada, no se avisa: quedarse
  // callado de más es mejor que un globo por cada falla mientras trabajás.
  bool focused;
  try {
    focused = await windowManager.isFocused();
  } catch (_) {
    return;
  }
  if (focused) return;

  _noticedAt = DateTime.now();
  final subtitle = fault.where.isEmpty ? 'Keel' : fault.where;
  // Con tope: un `osascript` que se queda esperando algo no puede quedarse
  // con un aviso de que otra cosa falló.
  await Process.run('osascript', [
    '-e',
    'display notification ${_applescript(fault.message)} '
        'with title "Keel — algo falló" '
        'subtitle ${_applescript(subtitle)}',
  ]).timeout(_kNoticeBudget, onTimeout: () => ProcessResult(0, 1, '', ''));
}

/// Un string de AppleScript. El mensaje viene de una excepción, así que
/// puede traer comillas y barras adentro: sin escaparlas, `osascript` no
/// falla — hace otra cosa.
String _applescript(String text) {
  final flat = text.replaceAll('\n', ' ').trim();
  final escaped = flat.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"${escaped.length > 180 ? '${escaped.substring(0, 180)}…' : escaped}"';
}
