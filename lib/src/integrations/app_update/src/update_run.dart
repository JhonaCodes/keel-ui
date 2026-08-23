part of '../app_update.dart';

enum UpdateStepResult { ok, skipped, failed }

/// Un paso de la actualización, con lo que contestó git.
class UpdateStep {
  const UpdateStep(this.label, this.result, [this.detail = '']);

  final String label;
  final UpdateStepResult result;
  final String detail;

  bool get failed => result == UpdateStepResult.failed;
}

class KeelUpdateReport {
  const KeelUpdateReport({required this.steps, required this.pulled});

  final List<UpdateStep> steps;

  /// El código nuevo está en el disco. Ojo: **no** es "ya estás corriendo la
  /// versión nueva" — para eso falta reconstruir.
  final bool pulled;

  bool get ok => pulled && !steps.any((step) => step.failed);
}

/// Trae los commits nuevos al repo de Keel. Nada más.
///
/// Un solo paso, y a propósito. Construir necesita el `flutter` del PATH que
/// tenés en tu terminal, y una app de macOS arranca con un PATH mínimo
/// —`/usr/bin:/bin:/usr/sbin:/sbin`— donde `git` está y `flutter` no.
/// Intentarlo igual sería un "no se encontró el comando" disfrazado de bug
/// de Keel. Por eso la reconstrucción se le pasa a la Terminal, que sí abre
/// tu shell de verdad.
Future<KeelUpdateReport> runKeelUpdate(KeelUpdatePlan plan) async {
  final root = plan.source.root;
  final pull = await _git(['pull', '--ff-only'], cwd: root);

  return KeelUpdateReport(
    pulled: pull.ok,
    steps: [
      UpdateStep(
        'Traer `${plan.version.branch}` de origin',
        pull.ok ? UpdateStepResult.ok : UpdateStepResult.failed,
        pull.output.isEmpty ? 'Ya estaba al día.' : pull.output,
      ),
    ],
  );
}

/// El comando que reconstruye y vuelve a abrir Keel.
String rebuildCommand(String root) =>
    "cd '${root.replaceAll("'", r"'\''")}' && flutter run -d macos";

/// Abre la Terminal reconstruyendo, y cierra Keel.
///
/// Cerrar es parte del trabajo y no un efecto colateral: el binario que
/// estás corriendo es el que `flutter run` va a reemplazar, y dos Keel
/// abiertos sobre la misma base LMDB es exactamente el problema que la app
/// evita en todos lados.
///
/// La salida es la ordenada —la misma que Cmd+Q— para que el respaldo de
/// cierre alcance a correr.
Future<void> rebuildAndRelaunch(String root) async {
  final command = rebuildCommand(root);
  final script =
      'tell application "Terminal"\n'
      '  activate\n'
      '  do script ${_applescriptString(command)}\n'
      'end tell';

  final opened = await Process.run('osascript', ['-e', script]);
  if (opened.exitCode != 0) {
    Log.e('No pude abrir la Terminal para reconstruir: ${opened.stderr}');
    return;
  }
  await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
}

String _applescriptString(String text) {
  final escaped = text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
