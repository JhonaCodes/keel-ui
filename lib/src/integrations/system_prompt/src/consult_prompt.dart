part of '../system_prompt.dart';

/// LOS DOS EXTREMOS DE UNA CONSULTA entre miembros del canal.
///
/// Qué dicen: [consultRequestPrompt] es lo que recibe el consultado —quién
/// pregunta, el extracto con la pregunta, y el límite: responde desde su
/// especialidad, sin escribir ni abrir trabajo paralelo. [consultAnswerPrompt]
/// es lo que vuelve al que preguntó, para que siga su paso con esa respuesta.
///
/// Por qué existen: una mención `@handle` dispara un turno real. Sin estos
/// marcos, el consultado cree que le pasaron el trabajo y se pone a
/// implementar adentro del paso de otro; y el que preguntó recibe un texto
/// suelto sin saber que es la respuesta que estaba esperando.
///
/// Al consultado le llega SOLO el párrafo donde lo nombran y el anterior —
/// eso se lo avisa [companionsPrompt] al que escribe la mención.
///
/// Quién los usa: el ciclo de consultas de `_runTurn` en
/// `modules/projects/viewmodel/projects_viewmodel.dart`.
String consultRequestPrompt({
  required String askerHandle,
  required String askerRole,
  required String excerpt,
}) {
  return '@$askerHandle ($askerRole) te pide una consulta acotada:\n\n'
      '$excerpt\n\n'
      'Respondé solo desde tu especialidad con evidencia concreta. Esta '
      'consulta no habilita escribir ni abrir trabajo paralelo: el '
      'responsable del caso sintetiza tu respuesta y decide el siguiente nodo.';
}

String consultAnswerPrompt({
  required String targetHandle,
  required String answer,
}) {
  return '@$targetHandle respondió tu consulta:\n\n$answer\n\n'
      'Seguí con tu paso usando esa respuesta.';
}
