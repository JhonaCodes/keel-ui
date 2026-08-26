part of '../system_prompt.dart';

/// EL PLAN DE LA SESIÓN, TAL COMO ESTÁ, dentro del turno.
///
/// Qué dice: si la sesión no tiene plan, la orden de escribirlo antes que
/// nada (entre 3 y 8 puntos verificables, con el puesto de cada uno); si ya
/// tiene, el plan entero con sus marcas `[x]` / `[ ]` / `[-]` y cómo
/// marcarlo al cerrar el turno.
///
/// Dos variantes según las tools disponibles: con `set_session_plan` /
/// `complete_plan_items` (claude) o con los bloques cercados ```plan y
/// ```cumplido (codex, que no tiene esas tools).
///
/// Quién lo usa: `_turnSystemPrompt` y el armado del turno en
/// `modules/projects/viewmodel/projects_viewmodel.dart`.
///
/// El estado real del plan, dentro del turno.
///
/// Nombrar las tools no alcanzaba: `complete_plan_items` pide "el texto
/// exacto" de puntos que el agente nunca vio, y decidir si escribir el plan
/// quedaba en manos de que el modelo leyera su paso como "planificar" —el
/// paso 1 de tdd se llama "Charter" y nadie lo llamó así—. Las dos son
/// decisiones que la app puede tomar por él.
String planSectionPrompt(
  Session? session, {
  required bool isConsult,
  required bool hasPlanTools,
}) {
  final plan = session?.plan ?? const <SessionPlanItem>[];

  if (plan.isEmpty) {
    // Un consultado no planifica la sesión de otro: contesta y se va.
    if (isConsult) return '';
    // Codex no tiene las tools del plan: escribe con el bloque fenced.
    final como = hasPlanTools
        ? 'escribilo con `set_session_plan`'
        : 'escribilo dejando en tu respuesta un bloque exactamente así:\n'
              '```plan\n'
              'puntos:\n'
              'Primer punto concreto y verificable | puesto que lo hace\n'
              'Segundo punto\n'
              '```\n'
              'El puesto (tras el último "|") es opcional; no uses "|" '
              'dentro del texto del punto. Escribilo';
    return 'PLAN DE LA SESIÓN: esta sesión todavía no tiene plan, y el plan '
        'es lo que el usuario mira para saber qué falta. ANTES que nada en '
        'este turno, $como: entre 3 y 8 puntos '
        'concretos y verificables que haya que cumplir para darla por '
        'terminada — no las etapas del workflow, que ya se ven aparte. A '
        'cada punto ponele el PUESTO que lo tiene que hacer cuando esté '
        'claro. No importa cómo se llame tu paso: si no hay plan, lo '
        'escribís vos. Después seguí con tu trabajo normal.\n'
        'Cada punto se trabaja después en su propia vuelta del workflow: '
        'un punto es una unidad entregable, no una sesión de media hora.';
  }

  final buffer = StringBuffer();
  buffer.writeln(
    'PLAN DE LA SESIÓN (${plan.doneCount} de ${plan.length} cumplidos'
    '${plan.discardedCount == 0 ? '' : ', ${plan.discardedCount} descartados por el usuario — marcados [-], no se hacen'}) — es '
    'lo que el usuario mira para saber qué falta:',
  );
  for (final item in plan) {
    final puesto = item.ownerRole == null ? '' : ' (${item.ownerRole})';
    // Tres estados y no dos: `[-]` es un punto que el usuario sacó de la
    // mesa. Sin esa marca el agente lo lee como pendiente y sale a
    // hacerlo, que es justo lo que se acaba de decidir que no.
    final marca = item.discarded ? '[-]' : (item.done ? '[x]' : '[ ]');
    buffer.writeln('$marca$puesto ${item.text}');
  }

  if (isConsult) {
    buffer.writeln(
      'Va como contexto: el plan lo marca quien está ejecutando el paso — '
      'en este turno no tenés las tools del plan.',
    );
    return buffer.toString().trim();
  }

  if (hasPlanTools) {
    buffer.writeln(
      'Al cerrar tu turno marcá con `complete_plan_items` los puntos que '
      'efectivamente resolviste, copiando su texto tal como está acá '
      'arriba — la comparación ignora mayúsculas, acentos y puntuación, '
      'pero no adivina: cambiá una palabra y no lo encuentra. Solo esos: '
      'marcar de más deja al usuario ciego. Si el plan quedó viejo, '
      'reescribilo entero con `set_session_plan` — lo hecho que no cambie de '
      'texto se conserva marcado.',
    );
  } else {
    buffer.writeln(
      'Al cerrar tu turno marcá lo que efectivamente resolviste dejando en '
      'tu respuesta un bloque así, un punto por línea con su texto tal '
      'como está acá arriba:\n'
      '```cumplido\n'
      'puntos:\n'
      'Texto del punto resuelto\n'
      '```\n'
      'Solo esos: marcar de más deja al usuario ciego. Si el plan quedó '
      'viejo, reescribilo entero con un bloque ```plan — lo hecho que no '
      'cambie de texto se conserva marcado.',
    );
  }
  buffer.writeln(
    'El plan es el contrato de la sesión: terminados los pasos, si queda un '
    'punto sin cumplir la sesión NO se da por terminada y pasa a '
    'verificación. Si algo de tu paso queda afuera, decilo en el momento.',
  );
  return buffer.toString().trim();
}
