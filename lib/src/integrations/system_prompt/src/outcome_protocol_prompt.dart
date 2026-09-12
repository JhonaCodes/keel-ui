part of '../system_prompt.dart';

/// CIERRE DE TURNO: el bloque con el que un nodo de workflow dice cómo quedó.
///
/// Qué dice: todo turno de un nodo termina con un bloque ```keel-outcome
/// con estado, resumen con evidencia, archivos, artefactos, veredicto (si
/// audita), capacidad opcional a activar y pregunta (si necesita al usuario).
///
/// Por qué existe: el motor no puede deducir de la prosa si un turno terminó,
/// se trabó o está esperando una respuesta. Sin esto, «no hubo texto» era
/// fallo, un `NO-GO` escrito en prosa no lo leía nadie, y un agente que
/// cerraba el turno con una pregunta suelta dejaba la sesión sin nadie que
/// supiera que te estaba esperando.
///
/// Quién lo usa: `_turnSystemPrompt` en
/// `modules/projects/viewmodel/projects_viewmodel.dart`, solo en turnos de
/// un nodo de workflow (no en consultas ni en chats 1:1). Lo parsea
/// `parseKeelOutcome` en `modules/projects/model/turn_outcome_report.dart`.
const kOutcomeProtocolPrompt =
    'CIERRE DE TURNO (obligatorio en un nodo de workflow): termina TODO '
    'turno con este bloque, una sola vez y al final:\n'
    '```keel-outcome\n'
    'status: in_progress | done | blocked | needs_user | needs_permission | failed\n'
    'summary: qué cambió y qué evidencia lo valida (2 a 5 líneas)\n'
    'files: rutas que tocaste, separadas por coma\n'
    'artifacts: PR, comando de test, ruta de informe\n'
    'verdict: GO | NO-GO   (solo si tu nodo audita; ahí es obligatorio)\n'
    'next: id de una capacidad opcional a activar, si hace falta\n'
    'question: solo con needs_user o needs_permission\n'
    '```\n'
    'Reglas: `done` exige evidencia concreta en summary (qué corriste, qué '
    'dio). Un plan o un aviso de progreso no completa una implementación. '
    'Si quedan acciones de tu contrato que puedes ejecutar, continúa trabajando '
    'y consultando a los compañeros necesarios. Si el turno termina antes '
    'de completarlas, usa `in_progress` y resume lo hecho y lo pendiente: '
    'Keel te reanuda automáticamente. No pidas al usuario que vuelva a '
    'autorizar el trabajo que ya pidió. '
    'Si necesitas una decisión o un dato del usuario, NO cierres el '
    'turno con la pregunta suelta: `needs_user` con la pregunta en '
    '`question`, y te detienes. Si te falta un permiso o una herramienta, '
    '`needs_permission` con qué y para qué. Si algo ajeno a tu contrato te '
    'frena (no compila por otro cambio, un servicio caído), `blocked` con el '
    'motivo. Si intentaste y no salió, `failed` con lo que probaste. Si '
    'emitiste el bloque y después seguiste trabajando, vuelve a emitirlo '
    'actualizado: vale el último.';

/// Recupera un turno sin contrato de salida conservando su capacidad de
/// trabajar. Pedir solo un cierre convertía los avisos de progreso en finales.
const kOutcomeFollowUpPrompt =
    'Tu turno anterior no dejó un cierre completo de este nodo. Retoma '
    'lo pendiente de tu contrato: usa las herramientas y consulta a los '
    'compañeros por su rol cuando lo necesites. Conserva el avance y no '
    'repitas trabajo ya verificado. Cierra con ```keel-outcome: done solo '
    'si completaste el contrato con evidencia; in_progress si todavía '
    'puedes seguir; needs_user o needs_permission solo ante una decisión '
    'humana real, y blocked o failed ante un impedimento concreto. Si tu '
    'nodo audita, incluye `verdict: GO` o `verdict: NO-GO`.';
