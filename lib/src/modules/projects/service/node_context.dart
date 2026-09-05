import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';

/// Tope por salida de dependencia dentro de la instrucción de un nodo.
const kDependencyOutputMaxChars = 1500;

/// Tope del resumen del caso que viaja a un nodo que arranca sin sesión.
const kSessionDigestMaxChars = 4000;

/// Lo que dejó cada dependencia cerrada de [node]: el nodo y su bloque de
/// cierre. Solo las que cerraron con salida; una dependencia sin bloque no
/// tiene nada que pasar.
List<({WorkNode node, TurnOutcomeReport report})> dependencyOutputs(
  ResolutionCase resolution,
  WorkNode node,
) => [
  for (final id in node.dependencyIds)
    for (final dependency in resolution.nodes)
      if (dependency.id == id &&
          dependency.status == WorkNodeStatus.done &&
          dependency.output != null)
        (node: dependency, report: dependency.output!),
];

/// La sección «lo que dejaron las dependencias» de la instrucción de un
/// nodo. Cada salida recortada a [kDependencyOutputMaxChars]: el nodo que
/// sigue necesita el resumen y los archivos, no el informe entero —para eso
/// tiene el repo.
String renderDependencyOutputs(
  List<({WorkNode node, TurnOutcomeReport report})> outputs,
) {
  final parts = <String>[];
  for (final entry in outputs) {
    final title = entry.node.title.isEmpty ? entry.node.id : entry.node.title;
    final report = entry.report;
    final verdict = switch (report.verdict) {
      TurnVerdict.go => ' · veredicto GO',
      TurnVerdict.noGo => ' · veredicto NO-GO',
      null => '',
    };
    final buffer = StringBuffer('[$title]$verdict\n${report.summary.trim()}');
    if (report.files.isNotEmpty) {
      buffer.write('\nArchivos: ${report.files.join(', ')}');
    }
    if (report.artifacts.trim().isNotEmpty) {
      buffer.write('\nArtefactos: ${report.artifacts.trim()}');
    }
    parts.add(_clip(buffer.toString(), kDependencyOutputMaxChars));
  }
  return parts.join('\n\n');
}

/// El estado del caso, nodo por nodo, para un turno que arranca sin la
/// sesión del CLI: qué cerró, qué falta, qué dejó cada uno. Determinista,
/// sin LLM y sin cuerpos del hilo: el resumen ES la compactación.
String sessionDigest(ResolutionCase resolution) {
  final lines = <String>[];
  for (final node in resolution.nodes) {
    final title = node.title.isEmpty ? node.id : node.title;
    final summary = node.output?.summary.trim() ?? '';
    final line = summary.isEmpty
        ? '- $title (${node.status.name})'
        : '- $title (${node.status.name}): ${_clip(summary, 400)}';
    lines.add(line);
  }
  final open = resolution.findings
      .where((finding) => finding.status.name != 'resolved')
      .map((finding) => '- hallazgo abierto: ${finding.evidence.summary}');
  lines.addAll(open);
  return _clip(lines.join('\n'), kSessionDigestMaxChars);
}

/// La dependencia cuya sesión de CLI puede reanudar [node] en vez de abrir
/// una nueva, o null si no hay ninguna.
///
/// Condiciones, todas: el nodo no exige dueño independiente, la dependencia
/// cerró, la corrió el MISMO dueño, y su sesión sigue registrada. Se mira
/// de la última dependencia a la primera: la más reciente es la que tiene
/// el contexto más útil.
String? reusableDependencyId({
  required WorkNode node,
  required List<WorkNode> nodes,
  required String ownerId,
  required String Function(String nodeId) ownerIdOf,
  required Set<String> liveExecutionIds,
  required String Function(String nodeId) executionIdFor,
  required bool requiresIndependentOwner,
}) {
  if (requiresIndependentOwner || ownerId.isEmpty) return null;
  for (final id in node.dependencyIds.reversed) {
    final dependency = nodes.where((entry) => entry.id == id).firstOrNull;
    if (dependency == null || dependency.status != WorkNodeStatus.done) {
      continue;
    }
    if (ownerIdOf(id) != ownerId) continue;
    if (!liveExecutionIds.contains(executionIdFor(id))) continue;
    return id;
  }
  return null;
}

String _clip(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max)}…';
