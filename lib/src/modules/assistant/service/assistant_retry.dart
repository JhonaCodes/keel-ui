/// Verbs the system prompt itself tells Keel AI trigger a block ("crear,
/// registrar, armar o configurar algo") — mirrored here so the retry
/// heuristic stays in lockstep with what the model is actually told.
const _creationVerbs = [
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
];

/// Whether any of [recentUserTexts] reads like a request to create/register
/// something. The only case where a Keel AI reply with zero action blocks
/// is worth an automatic retry instead of being treated as ordinary chat (a
/// question, small talk, etc).
///
/// Takes several recent user turns, not just the latest one: a real
/// conversation often goes "creá una estación para X" → Keel AI asks a
/// clarifying question or proposes a variant → user replies "sí, dale" — the
/// message that actually triggers the retry has no creation verb in it at
/// all, even though this is exactly the moment a missing block is most
/// confusing.
bool looksLikeCreationRequest(Iterable<String> recentUserTexts) {
  return recentUserTexts.any((text) {
    final lower = text.toLowerCase();
    return _creationVerbs.any((verb) => lower.contains(verb));
  });
}

/// Sent once, automatically, when Keel AI's reply to what looked like a
/// creation request contained no action block at all.
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
    'razonable: no hace falta ninguna herramienta, tool, API ni conexión '
    'para esto — el bloque de texto que ya se te explicó ES el mecanismo '
    'completo, y lo tenés disponible ahora mismo. No es que te falte algo. '
    'Tenés permiso explícito para contradecir lo que acabás de decir: fue '
    'un error, no una limitación real. Corregilo ahora mismo escribiendo '
    'ÚNICAMENTE el bloque de acción correspondiente al pedido — sin '
    'explicación, sin repetir que no podés, sin nada más.';
