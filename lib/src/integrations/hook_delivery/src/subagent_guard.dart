part of '../hook_delivery.dart';

/// El nombre del hook interno que aplica el cupo de subagentes de un nodo.
const kSubagentGuardHookName = 'keel-subagent-guard';

/// El hook que deniega la tarea interna N+1.
///
/// El cupo ya se le decía al modelo en el prompt, y `SubagentBudget` lo
/// observaba: cuando el evento de apertura llegaba, el CLI YA había abierto
/// el subagente y lo único posible era avisar. Un `PreToolUse` sobre `Task`
/// corre ANTES: cuenta en un archivo del workspace del turno (que muere con
/// el turno) y deniega con el motivo cuando el cupo se agotó. Cero es
/// «ninguno», que es lo que el prompt ya prometía y no podía garantizar.
Hook subagentGuardHook(int maxSubagents) => Hook(
  id: kSubagentGuardHookName,
  name: kSubagentGuardHookName,
  description:
      'Deniega la tarea interna que excede el cupo de subagentes del nodo.',
  event: HookEvent.preToolUse,
  matcher: 'Task',
  body: HookCommand(renderSubagentGuardScript(maxSubagents)),
  timeoutSeconds: kDefaultHookTimeoutSeconds,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// El contador vive junto al script: el wrapper lo invoca por ruta absoluta
/// dentro del workspace 0700 del turno, así que `dirname "$0"` es ese
/// directorio y el archivo desaparece con él.
String renderSubagentGuardScript(int maxSubagents) {
  final max = maxSubagents < 0 ? 0 : maxSubagents;
  return '''
keel_guard_dir="\$(cd "\$(dirname "\$0")" && pwd)"
keel_guard_file="\$keel_guard_dir/subagents.count"
keel_guard_count=\$(cat "\$keel_guard_file" 2>/dev/null || echo 0)
case "\$keel_guard_count" in
  ''|*[!0-9]*) keel_guard_count=0 ;;
esac
if [ "\$keel_guard_count" -ge $max ]; then
  printf '%s\\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Cupo de subagentes agotado ($max en este nodo). Resolvé el resto en este hilo."}}'
  exit 0
fi
echo \$((keel_guard_count + 1)) > "\$keel_guard_file"
printf '%s\\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
''';
}
