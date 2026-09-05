part of '../hook_delivery.dart';

/// El nombre del hook interno que aplica el tope de herramientas de un turno.
const kToolCapHookName = 'keel-tool-cap';

/// El hook que deniega la llamada a herramienta N+1.
///
/// Claude tiene `--max-turns` y ahí el tope del nodo se aplica solo. Codex
/// no tiene nada equivalente: un nodo codex corría sin freno hasta que el
/// modelo decidía parar, o hasta el vigilante. Este `PreToolUse` sin
/// matcher cuenta cada llamada en un archivo del workspace del turno y, al
/// llegar al tope, deniega con un motivo que le pide al modelo cerrar con
/// el bloque `keel-outcome`: el turno termina con estado, no cortado.
Hook toolCapHook(int maxToolCalls) => Hook(
  id: kToolCapHookName,
  name: kToolCapHookName,
  description: 'Deniega la llamada a herramienta que excede el tope del turno.',
  event: HookEvent.preToolUse,
  matcher: '',
  body: HookCommand(renderToolCapScript(maxToolCalls)),
  timeoutSeconds: kDefaultHookTimeoutSeconds,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// Mismo esquema que el cupo de subagentes: el contador vive junto al
/// script, dentro del workspace 0700 del turno, y muere con él.
String renderToolCapScript(int maxToolCalls) {
  final max = maxToolCalls < 1 ? 1 : maxToolCalls;
  return '''
keel_cap_dir="\$(cd "\$(dirname "\$0")" && pwd)"
keel_cap_file="\$keel_cap_dir/toolcalls.count"
keel_cap_count=\$(cat "\$keel_cap_file" 2>/dev/null || echo 0)
case "\$keel_cap_count" in
  ''|*[!0-9]*) keel_cap_count=0 ;;
esac
if [ "\$keel_cap_count" -ge $max ]; then
  printf '%s\\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Tope de herramientas del turno alcanzado ($max). No llames más herramientas: cerrá ahora con el bloque keel-outcome y el estado real de lo que quedó."}}'
  exit 0
fi
echo \$((keel_cap_count + 1)) > "\$keel_cap_file"
printf '%s\\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
''';
}
