part of '../hook_delivery.dart';

/// Keeps at most N subagents running at once in a claude turn.
///
/// Two hooks share one counter next to their scripts, inside the turn's 0700
/// workspace: `PreToolUse` on `Task` (claude reports the tool as `Agent`,
/// and `Task` matches it) counts one up or denies, and `SubagentStop` counts
/// one down when a subagent really ends — `PostToolUse` fires as soon as a
/// background subagent is launched, so it cannot tell when it finished
/// (verified with claude 2.1.280). A `mkdir` lock keeps two launches made in
/// the same instant from both seeing room for one.
abstract final class SubagentParallelGuard {
  static const startHookName = 'keel-subagent-parallel';
  static const stopHookName = 'keel-subagent-parallel-stop';

  static List<Hook> hooks(int maxParallel) => [
    Hook(
      id: startHookName,
      name: startHookName,
      description:
          'Deniega el subagente que excede los que pueden correr a la vez.',
      event: HookEvent.preToolUse,
      matcher: 'Task',
      body: HookCommand(renderStartScript(maxParallel)),
      timeoutSeconds: kDefaultHookTimeoutSeconds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
    Hook(
      id: stopHookName,
      name: stopHookName,
      description: 'Libera el lugar de un subagente que terminó.',
      event: HookEvent.subagentStop,
      matcher: '',
      body: HookCommand(renderStopScript()),
      timeoutSeconds: kDefaultHookTimeoutSeconds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
  ];

  static const _counter = '''
keel_par_dir="\$(cd "\$(dirname "\$0")" && pwd)"
keel_par_file="\$keel_par_dir/subagents.running"
keel_par_lock="\$keel_par_dir/subagents.lock"
keel_par_try=0
while ! mkdir "\$keel_par_lock" 2>/dev/null; do
  keel_par_try=\$((keel_par_try + 1))
  [ "\$keel_par_try" -gt 100 ] && break
  sleep 0.05
done
keel_par_count=\$(cat "\$keel_par_file" 2>/dev/null || echo 0)
case "\$keel_par_count" in
  ''|*[!0-9]*) keel_par_count=0 ;;
esac
''';

  static String renderStartScript(int maxParallel) {
    final max = maxParallel < 0 ? 0 : maxParallel;
    return '''
cat >/dev/null
$_counter
if [ "\$keel_par_count" -ge $max ]; then
  rmdir "\$keel_par_lock" 2>/dev/null
  printf '%s\\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Ya hay $max subagentes corriendo a la vez, el máximo de Keel. Espera a que termine alguno o resuélvelo en este hilo."}}'
  exit 0
fi
echo \$((keel_par_count + 1)) > "\$keel_par_file"
rmdir "\$keel_par_lock" 2>/dev/null
exit 0
''';
  }

  static String renderStopScript() => '''
cat >/dev/null
$_counter
if [ "\$keel_par_count" -gt 0 ]; then
  echo \$((keel_par_count - 1)) > "\$keel_par_file"
fi
rmdir "\$keel_par_lock" 2>/dev/null
exit 0
''';
}
