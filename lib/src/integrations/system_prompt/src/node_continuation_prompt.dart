part of '../system_prompt.dart';

/// LA CONTINUACIÓN de un nodo cuyo turno se cortó para entregarle un mensaje.
///
/// Qué dice: que no es un encargo nuevo, el mensaje que cortó el turno (o que
/// ya se contestó en el canal) y que siga desde el último paso completo.
///
/// Por qué existe: un proveedor que no recibe texto a mitad de turno (codex,
/// OpenCode, las APIs) solo puede recibir un mensaje urgente si se le mata el
/// proceso. Relanzar el nodo con su contrato completo hacía que el agente lo
/// leyera como un encargo nuevo y se reorientara desde cero: volvía a leer el
/// repo y a verificar lo que ya había hecho. Va solo cuando el turno reanuda
/// la misma sesión del CLI, donde el contrato ya está en su conversación.
///
/// Quién lo usa: `_runWorkflow` en
/// `modules/projects/viewmodel/projects_viewmodel.dart`.
String nodeContinuationPrompt({
  required WorkNode node,

  /// El mensaje que cortó el turno, ya con su contexto. Vacío cuando se
  /// contestó en el canal antes de retomar el nodo.
  required String message,
}) {
  final title = node.title.isEmpty ? node.id : node.title;
  final reason = message.trim().isEmpty
      ? 'para atender un mensaje del usuario que ya se contestó en el canal.'
      : 'para entregarte este mensaje del usuario:\n\n${message.trim()}';
  return 'CONTINUACIÓN DEL NODO "$title". No es un encargo nuevo: tu turno '
      'anterior de este nodo se cortó $reason\n\n'
      'Tu conversación y todo lo que escribiste en disco siguen ahí. Aplica el '
      'mensaje y sigue desde el último paso que completaste. El paso que '
      'estaba a medias cuando se cortó (un test corriendo, una edición) puede '
      'no haber terminado: revisa solo ese. No vuelvas a leer ni a verificar '
      'lo que ya hiciste. Al cerrar, termina con el bloque ```keel-outcome '
      'como siempre.';
}
