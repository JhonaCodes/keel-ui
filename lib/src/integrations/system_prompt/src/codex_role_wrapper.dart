part of '../system_prompt.dart';

/// EL ENVOLTORIO DEL STACK DE INSTRUCCIONES PARA CODEX.
///
/// Qué dice: dos delimitadores —`### Instrucciones de tu rol (fijas para
/// toda la conversación)` y `### Fin de instrucciones`— que encierran el
/// system prompt del member antes del pedido del usuario.
///
/// Por qué existe: Codex no tiene flag de system prompt. Sin los
/// delimitadores, las instrucciones del rol y el pedido del usuario llegan
/// como un solo texto y el modelo trata las primeras como parte del pedido:
/// contesta sobre sus propias instrucciones en vez de obedecerlas. Solo van
/// en el PRIMER turno de una sesión; los turnos con resume ya las tienen en
/// el historial del thread.
///
/// Quién lo usa: `buildCodexPrompt` en `llm/codex/codex_arguments.dart`.
String codexRoleWrappedPrompt({
  required String prompt,
  required String systemPrompt,
}) {
  return '### Instrucciones de tu rol (fijas para toda la conversación)\n'
      '$systemPrompt\n'
      '### Fin de instrucciones\n\n'
      '$prompt';
}
