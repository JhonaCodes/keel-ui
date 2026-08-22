part of '../hook_delivery.dart';

/// Un problema al preparar los archivos de un hook, contado en castellano.
class HookRenderIssue {
  final String hookName;
  final String message;

  const HookRenderIssue(this.hookName, this.message);

  @override
  String toString() => '$hookName: $message';
}

/// Los archivos que hay que escribir para que estos hooks corran:
/// `{nombre de archivo: contenido}`, más lo que no se pudo preparar.
///
/// Para un hook con cuerpo de tool salen DOS archivos —el wrapper y el
/// código de la tool— porque el CLI ejecuta un comando, no una entidad de
/// la base.
({Map<String, String> files, List<HookRenderIssue> issues}) renderHookFiles(
  List<Hook> hooks, {
  required Map<String, Tool> toolsByName,
  required Map<String, String> secretValues,
}) {
  final files = <String, String>{};
  final issues = <HookRenderIssue>[];

  for (final hook in hooks) {
    switch (hook.body) {
      case HookCommand(:final command):
        // El comando va a su propio archivo en vez de inline, por una razón
        // concreta: un hook que bloquea hace `exit 2`, y si estuviera
        // inline eso terminaría el wrapper antes de que pueda marcar el
        // stderr. En un archivo aparte, el `exit` corta el hijo y el wrapper
        // sigue vivo para dejar la marca.
        final bodyFile = '${hook.name}.body.sh';
        files[bodyFile] = '#!/usr/bin/env bash\n$command\n';
        files[hook.scriptFileName] = _wrapper(
          hook,
          secretNames: const [],
          secretValues: secretValues,
          invocation: 'bash "\$keel_hook_dir"/${_shellQuote(bodyFile)}',
        );

      case HookToolRef(:final toolName):
        final tool = toolsByName[toolName];
        if (tool == null) {
          issues.add(
            HookRenderIssue(
              hook.name,
              'apunta a la tool "$toolName", que ya no existe',
            ),
          );
          continue;
        }
        final missing = tool.secretNames
            .where((name) => (secretValues[name] ?? '').isEmpty)
            .toList();
        if (missing.isNotEmpty) {
          // Falla CERRADO, igual que una tool con secrets pendientes: correr
          // un guardarraíl a medias es peor que no correrlo, porque parece
          // que funcionó.
          issues.add(
            HookRenderIssue(
              hook.name,
              'le faltan valores de secrets: ${missing.join(', ')}',
            ),
          );
          continue;
        }

        // `.body.` en el medio y no solo la extensión: una tool bash daría
        // `<hook>.sh`, que es exactamente el nombre del wrapper — el wrapper
        // se sobrescribiría con el código y terminaría llamándose a sí
        // mismo, en recursión infinita.
        final codeFile = '${hook.name}.body.${tool.runtime.fileExtension}';
        files[codeFile] = tool.code;
        files[hook.scriptFileName] = _wrapper(
          hook,
          secretNames: tool.secretNames,
          secretValues: secretValues,
          invocation:
              '${tool.runtime.executable} "\$keel_hook_dir"/'
              '${_shellQuote(codeFile)}',
        );
    }
  }

  return (files: files, issues: issues);
}

/// El script que el CLI ejecuta de verdad.
///
/// Existe por tres razones concretas: exporta SOLO los secrets que este hook
/// declara (el proceso del CLI hereda el entorno de la app, así que meterlos
/// ahí se los daría a todo lo demás), resuelve la ruta del código cuando el
/// cuerpo es una tool, y marca el stderr cuando el hook bloquea.
///
/// La entrada estándar no se toca: el CLI le manda al hook el evento como
/// JSON por stdin, y el cuerpo la hereda tal cual.
String _wrapper(
  Hook hook, {
  required List<String> secretNames,
  required Map<String, String> secretValues,
  required String invocation,
}) {
  final exports = [
    for (final name in secretNames)
      'export $name=${_shellQuote(secretValues[name] ?? '')}',
  ];

  return '''
#!/usr/bin/env bash
# keel-ui · hook "${hook.name}" · ${hook.event.alias}
# Generado por turno. No editar: se reescribe en cada lanzamiento.
keel_hook_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
${exports.join('\n')}
$invocation
keel_hook_status=\$?
if [ "\$keel_hook_status" -eq 2 ]; then
  printf '\\n[$kHookDenialMarker ${hook.name}]\\n' >&2
fi
exit \$keel_hook_status
''';
}
