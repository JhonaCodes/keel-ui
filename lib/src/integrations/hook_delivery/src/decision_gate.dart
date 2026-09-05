part of '../hook_delivery.dart';

/// El nombre del hook interno que pide permiso a Keel antes de una tool que
/// escribe. También es el nombre de sus archivos en el workspace del turno.
const kDecisionGateHookName = 'keel-decision-gate';

/// Cuánto puede esperar el gate a que la persona conteste. Seis horas, el
/// mismo criterio que `kMcpToolTimeoutMillis`: lo bastante para que nadie lo
/// toque yendo a almorzar, lo bastante finito para que un cuelgue de verdad
/// no quede vivo para siempre.
const kDecisionGateTimeoutSeconds = 21600;

/// Las tools que pasan por el gate: todo lo que escribe o ejecuta.
const kDecisionGateTools = <String>[
  'Bash',
  'Edit',
  'Write',
  'MultiEdit',
  'NotebookEdit',
];

/// A dónde le pregunta el gate de un turno.
///
/// La URL lleva proyecto, sesión y perfil (igual que los MCP propios), así
/// que el script no manda ids y no puede pedirle permiso en nombre de otro
/// turno. El token es el del servidor de decisiones, por arranque.
class DecisionGateSpec {
  final String url;
  final String token;

  const DecisionGateSpec({required this.url, required this.token});
}

/// El hook, como una entrada más del catálogo de este turno.
///
/// No vive en el catálogo del usuario a propósito: no se apaga, no se
/// exporta, no depende de acordarse de asignarlo. Es la única forma de que
/// «permitir» sea una decisión de la persona y no un setting global que el
/// CLI ya no consulta.
Hook decisionGateHook(DecisionGateSpec spec) => Hook(
  id: kDecisionGateHookName,
  name: kDecisionGateHookName,
  description:
      'Suspende una tool que escribe hasta que la persona la permite o la '
      'rechaza desde Keel.',
  event: HookEvent.preToolUse,
  matcher: kDecisionGateTools.join('|'),
  body: HookCommand(renderDecisionGateScript(spec)),
  timeoutSeconds: kDecisionGateTimeoutSeconds,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// El script del gate. Python y no bash con `curl`: hay que leer el JSON del
/// evento por stdin, armar otro, y esperar una respuesta HTTP sin plazo —
/// tres cosas que en bash puro terminan dependiendo de `jq` y de flags de
/// `curl` que cambian entre máquinas. `python3` viene con macOS.
///
/// Lo que devuelve es el contrato de PreToolUse de los dos CLIs (y del
/// bridge de las APIs, que lee lo mismo): `permissionDecision` allow o deny,
/// con el motivo. Si Keel no contesta —se cerró, se cayó el servidor— es
/// deny, nunca allow por defecto.
String renderDecisionGateScript(DecisionGateSpec spec) {
  final url = jsonEncode(spec.url);
  final token = jsonEncode(spec.token);
  // El programa se carga en una variable y se pasa con `-c`, NUNCA con
  // `python3 - <<EOF`: un heredoc reemplaza el stdin, y el stdin es donde
  // el CLI manda el evento con la tool y su entrada. Probado contra claude
  // 2.1.232: con el heredoc el hook corría, leía el heredoc como evento y el
  // CLI ejecutaba la tool igual.
  return """
read -r -d '' KEEL_GATE_PY <<'KEEL_GATE' || true
import json, sys, urllib.request
try:
    event = json.load(sys.stdin)
except Exception:
    event = {}
payload = json.dumps({
    "tool_name": event.get("tool_name", ""),
    "tool_input": event.get("tool_input", {}),
}).encode("utf-8")
request = urllib.request.Request(
    $url,
    data=payload,
    headers={
        "Authorization": "Bearer " + $token,
        "Content-Type": "application/json",
    },
)
try:
    with urllib.request.urlopen(request, timeout=$kDecisionGateTimeoutSeconds) as response:
        decision = json.load(response)
except Exception as error:
    decision = {"decision": "deny", "reason": "Keel no contestó al gate: %s" % error}
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision.get("decision", "deny"),
        "permissionDecisionReason": decision.get("reason", ""),
    }
}))
KEEL_GATE
python3 -c "\$KEEL_GATE_PY"
""";
}
