/// Las dos decisiones del ciclo del modo plan, sacadas de los ViewModels.
///
/// Están acá porque son idénticas en los dos lados —el chat 1:1 y la sesión
/// de proyecto— y porque son lo único del ciclo que se puede probar sin
/// levantar un turno entero. Adentro de un ViewModel de 4000 líneas, para
/// afirmar que un plan aprobado viaja con su texto había que simular un CLI.
library;

/// ¿Hay que preguntar si se implementa?
///
/// Se pregunta solo si el turno planificó y llegó al final por su cuenta. Dos
/// casos dicen que no aunque haya plan:
///
/// - [stopped]: frenar un turno a mano es tomar el control, no pedir permiso.
/// - [hasQueuedMessages]: si escribiste algo mientras planificaba, ya
///   decidiste seguir por otro lado — y en un instante sale ese turno. La
///   tarjeta quedaría flotando sobre un agente que ya está en otra cosa.
bool shouldAskToImplement({
  required bool planMode,
  required bool stopped,
  required bool hasAnswer,
  required bool hasQueuedMessages,
}) => planMode && !stopped && hasAnswer && !hasQueuedMessages;

/// El pedido que sale cuando aprobás un plan.
///
/// Lleva el plan escrito adentro y no solo la confianza en el `--resume`. Si
/// la sesión del CLI murió y hay que reintentar sin ella —cosa que el
/// ViewModel de proyectos hace solo, borrando el id y volviendo a correr—, un
/// agente que lee «implementá lo acordado» sin saber qué se acordó implementa
/// cualquier cosa, en silencio. El texto es la red.
String planApprovalRequest(String? plan) {
  const heading =
      'Aprobé el plan. Implementalo ahora, tal como quedó: no lo vuelvas a '
      'proponer ni lo rediseñes.';
  final trimmed = plan?.trim();
  if (trimmed == null || trimmed.isEmpty) return heading;
  return '$heading\n\n'
      'El plan aprobado, para que no dependa de la sesión:\n\n$trimmed';
}
