part of '../hook_delivery.dart';

/// El handle reservado del asistente de la app. Se repite acá en vez de
/// importar el módulo `assistant` por una constante — mismo criterio que
/// `kKeelAiSkillNameForExport` en `catalog_shape`.
const kKeelAiHandleForHooks = 'keelai';

/// Qué hooks corren en un turno, y qué quedó afuera y por qué.
class ResolvedHooks {
  final List<Hook> hooks;

  /// Lo que NO se aplicó, en castellano y listo para mostrar. Un hook que
  /// no corre donde lo asignaste tiene que decirlo: el silencio se lee como
  /// "está protegido".
  final List<String> notes;

  const ResolvedHooks({this.hooks = const [], this.notes = const []});

  bool get isEmpty => hooks.isEmpty;
}

/// Los hooks de este turno: los globales, más los del perfil, más los de la
/// estación — por nombre y sin repetir.
///
/// Tres exclusiones, todas deliberadas:
///
/// - **Los apagados** no se escriben. Es lo que hace que apagar uno sea la
///   forma barata de destrabarse.
/// - **Los que no existen en este proveedor** se descartan y se anotan. Un
///   hook de `Notification` no existe en codex, y fingir que corre sería
///   peor que decir que no.
/// - **Keel AI no recibe NINGUNO.** No es una excepción de conveniencia: es
///   la salida de emergencia. Un hook mal escrito puede trabar a todos los
///   agentes, y la forma de arreglarlo es pedirle a Keel AI que lo apague.
///   Si a él también lo trabara, no habría salida.
ResolvedHooks resolveHooks({
  required List<Hook> catalog,
  required HookProvider provider,
  AgentProfile? profile,
  Station? station,
}) {
  if (profile?.name == kKeelAiHandleForHooks) {
    return const ResolvedHooks(
      notes: [
        'Keel AI corre sin hooks a propósito: es a quien le pedís apagarlos '
            'cuando uno te traba.',
      ],
    );
  }

  final wanted = <String>{
    for (final hook in catalog)
      if (hook.isGlobal) hook.name,
    ...?profile?.hooks,
    ...?station?.hookNames,
  };

  final hooks = <Hook>[];
  final notes = <String>[];
  final unsupported = <String>[];

  for (final hook in catalog) {
    if (!wanted.contains(hook.name)) continue;
    if (!hook.enabled) continue;
    if (!hook.event.runsOn(provider)) {
      unsupported.add('${hook.name} (${hook.event.label})');
      continue;
    }
    hooks.add(hook);
  }

  if (unsupported.isNotEmpty) {
    notes.add(
      'Sin aplicar en ${provider.label}: ${unsupported.join(', ')} — ese '
      'evento solo existe en Claude.',
    );
  }

  return ResolvedHooks(hooks: hooks, notes: notes);
}
