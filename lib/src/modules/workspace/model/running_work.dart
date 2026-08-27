/// Qué está trabajando ahora mismo, contado en un solo lugar.
///
/// El mismo `where((session) => session.isRunning).length` estaba escrito
/// tres veces —en la integración de update, en la de worktree y en el MCP del
/// asistente— y ninguna de las tres se veía en pantalla. La app sabía
/// perfectamente qué estaba corriendo y no lo decía en ningún lado.
///
/// **Qué NO cuenta, a propósito:** `SessionSubagent.isRunning`. Ese sí se
/// persiste, y un subagente que quedó en fase `thinking` cuando cerraste la
/// app reporta `true` para siempre — un contador que se apoye en él nunca
/// vuelve a cero. `Session.isRunning` también se persiste pero se fuerza a
/// `false` al abrir la app, así que ese sí es confiable.
library;

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';

/// Las sesiones de [project] que están corriendo un turno ahora.
int runningSessionsOf(Project project) =>
    project.sessions.where((session) => session.isRunning).length;

/// Si algo de este proyecto está trabajando.
bool isProjectRunning(Project project) =>
    project.sessions.any((session) => session.isRunning);

/// Los ids de los proyectos con trabajo en curso.
Set<String> runningProjectIds(Iterable<Project> projects) => {
  for (final project in projects)
    if (isProjectRunning(project)) project.id,
};

/// Los ids de los agentes sueltos que están contestando.
Set<String> runningAgentIds(Iterable<Agent> agents) => {
  for (final agent in agents)
    if (agent.isStreaming) agent.id,
};

/// Todo lo que está corriendo, sumado.
///
/// Cuenta TURNOS y no proyectos: un proyecto con dos sesiones trabajando son
/// dos cosas pasando, y decir «1» ahí escondería la mitad.
int totalRunningWork({
  required Iterable<Project> projects,
  required Iterable<Agent> agents,
  int thinkingRequirements = 0,
}) {
  var total = thinkingRequirements;
  for (final project in projects) {
    total += runningSessionsOf(project);
  }
  for (final agent in agents) {
    if (agent.isStreaming) total++;
  }
  return total;
}
