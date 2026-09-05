import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';

/// Qué está haciendo la sesión que tomó un requerimiento, en una frase.
///
/// Antes el que pedía solo veía «tomado» y nada más: no había forma de saber
/// si del otro lado había un agente trabajando, uno esperando al usuario, o
/// nadie. Null cuando no hay sesión (todavía no lo tomaron, o se borró).
String? requirementTargetActivity(Session? session) {
  if (session == null) return null;
  if (session.waitingForUser) return 'esperándote: hay una decisión pendiente';
  if (session.isRunning) {
    final phase = switch (session.liveTurn?.phase) {
      TurnPhase.thinking => 'pensando',
      TurnPhase.writing => 'escribiendo',
      TurnPhase.working => 'trabajando',
      null => 'entre turnos',
    };
    return 'trabajando ($phase)';
  }
  return switch (session.status) {
    SessionStatus.finished => 'terminó su sesión',
    SessionStatus.failed => 'su sesión falló o se detuvo',
    SessionStatus.running => 'sin turno vivo ahora',
  };
}
