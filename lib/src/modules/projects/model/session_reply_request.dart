/// El texto con el que entra al canal una respuesta que el usuario decidió
/// en el chat de Keel AI.
///
/// Está afuera del ViewModel por la misma razón que `planApprovalRequest`:
/// es lo único de este flujo que se puede afirmar sin levantar un turno, y
/// adentro de un ViewModel de 4000 líneas afirmarlo pedía simular un CLI.
///
/// Lo que el texto tiene que lograr es UNA cosa, y es la que hace útil a todo
/// el resto: que el miembro que preguntó lea esto como la continuación de SU
/// pregunta y no como una instrucción suelta. Por eso lleva las tres partes
/// juntas —a quién le habla, qué contesta y qué contestó—, y por eso el
/// `@handle` va primero: es además lo que hace que el turno le toque a él y
/// no al dueño del caso.
library;

const _quoteLimit = 600;

String assistantReplyRequest({
  required String? authorHandle,
  required String? nodeId,
  required DateTime askedAt,
  required String quotedText,
  required String answer,
}) {
  final mention = authorHandle == null || authorHandle.isEmpty
      ? ''
      : '@$authorHandle — ';
  final clock =
      '${askedAt.hour.toString().padLeft(2, '0')}:'
      '${askedAt.minute.toString().padLeft(2, '0')}';
  final node = nodeId == null || nodeId.isEmpty ? '' : ' en el nodo «$nodeId»';

  return '${mention}respuesta del usuario, traída por Keel AI desde el chat '
      'del sistema.\n'
      '\n'
      'Contesta ESTO, que escribiste a las $clock$node:\n'
      '\n'
      '${_asQuote(quotedText)}\n'
      '\n'
      'La respuesta:\n'
      '\n'
      '${answer.trim()}\n'
      '\n'
      'Seguí desde acá: esto resuelve esa pregunta, no abre un pedido nuevo.';
}

String _asQuote(String text) {
  final trimmed = text.trim();
  final bounded = trimmed.length > _quoteLimit
      ? '${trimmed.substring(0, _quoteLimit)}…'
      : trimmed;
  if (bounded.isEmpty) return '> (el mensaje no tenía texto)';
  return bounded.split('\n').map((line) => '> $line').join('\n');
}
