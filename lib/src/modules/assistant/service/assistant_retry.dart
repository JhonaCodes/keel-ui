/// Verbs that mean "act on the catalog" — creation/update AND deletion —
/// mirrored here so the retry heuristic stays in lockstep with what
/// `kKeelAiSystemPrompt` actually tells the model it can do.
const _actionVerbs = [
  'crea',
  'creá',
  'crear',
  'registra',
  'registrá',
  'registrar',
  'arma',
  'armá',
  'armar',
  'configura',
  'configurá',
  'configurar',
  'agrega',
  'agregá',
  'agregar',
  'asigna',
  'asigná',
  'asignar',
  'elimina',
  'eliminá',
  'eliminar',
  'borra',
  'borrá',
  'borrar',
  'quita',
  'quitá',
  'quitar',
];

/// Whether any of [recentUserTexts] reads like a request to create, update,
/// or delete something. The only case where a Keel AI reply with no action
/// block and no real tool call is worth an automatic retry instead of being
/// treated as ordinary chat (a question, small talk, etc).
///
/// Takes several recent user turns, not just the latest one: a real
/// conversation often goes "creá una estación para X" → Keel AI asks a
/// clarifying question or proposes a variant → user replies "sí, dale" — the
/// message that actually triggers the retry has no action verb in it at
/// all, even though this is exactly the moment a missing action is most
/// confusing.
bool looksLikeCreationRequest(Iterable<String> recentUserTexts) {
  return recentUserTexts.any((text) {
    final lower = text.toLowerCase();
    return _actionVerbs.any((verb) => lower.contains(verb));
  });
}

/// Sent once, automatically, when Keel AI's reply to what looked like an
/// action request neither called a real tool nor wrote an action block.
///
/// This fires right after the model's own prior turn — often an explicit
/// refusal ("no tengo herramientas para esto"), not just a missed format. A
/// model anchors to its own immediately-preceding answer more strongly than
/// to a system prompt, so a retry that just repeats the original
/// instruction is asking it to contradict itself one message later, in
/// exactly the context where that's hardest. This prompt names the refusal
/// directly and gives explicit permission to override it, instead of
/// pretending it didn't happen.
const kBlockRetryPrompt =
    'Lo que acabás de responder no es correcto, aunque te haya sonado '
    'razonable: tenés tools reales para esto en tu lista, con el prefijo '
    '`mcp__keelai-actions__` (create_skill, create_rule, '
    'create_or_update_agent, create_workflow, create_station, delete_skill, '
    'delete_rule, delete_agent, delete_workflow, delete_station) — no es '
    'que te falte una herramienta. Tenés permiso explícito para contradecir '
    'lo que acabás de decir: fue un error, no una limitación real. '
    'Corregilo ahora mismo llamando la tool correspondiente al pedido — sin '
    'explicación, sin repetir que no podés, sin nada más.';
