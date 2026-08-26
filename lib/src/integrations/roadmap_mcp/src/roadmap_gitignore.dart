part of '../roadmap_mcp.dart';

/// El bloque que se agrega al `.gitignore` del proyecto. El comentario no es
/// decorativo: quien abra ese archivo dentro de seis meses tiene que poder
/// entender de dónde salió la línea sin preguntarle a nadie.
const _roadmapIgnoreBlock =
    '\n# Keel administra el roadmap de este proyecto en $kRoadmapFolder/.\n'
    '# Es tuyo y de esta máquina, no del repo.\n'
    '$kRoadmapFolder/\n';

/// Deja `TASKS/` fuera del repo, sin pisar nada.
///
/// La carpeta la escribe un agente con sus propias tools de archivo —la app
/// nunca la crea— así que sin esto aparece en el `git status` del usuario y
/// termina comiteada junto al código. El roadmap es la libreta de trabajo de
/// Keel, no una entrega del proyecto.
///
/// Devuelve si escribió algo. No hace nada cuando:
///
/// - el proyecto no es un repo git. Ojo con esto: en un worktree `.git` es un
///   ARCHIVO y no una carpeta, así que preguntar solo por el directorio deja
///   afuera justo a los proyectos que corren en un worktree;
/// - el `.gitignore` ya cubre `TASKS/`, en cualquiera de las formas en que se
///   puede escribir.
///
/// Lo que a propósito NO hace: `git rm --cached`. Una `TASKS/` que ya estaba
/// comiteada sigue estándolo, porque sacarla del índice es un cambio que se
/// comitea y esa decisión es del usuario, no de la app.
Future<bool> ensureRoadmapIgnored(String projectPath) async {
  final root = projectPath.trim();
  if (root.isEmpty) return false;
  if (!_isGitRepository(root)) return false;

  final file = File('$root/.gitignore');
  final existing = await file.exists() ? await file.readAsString() : '';
  if (_alreadyIgnoresRoadmap(existing)) return false;

  // Un `.gitignore` que no termina en salto de línea dejaría la primera
  // línea del bloque pegada a la última regla del usuario — y una regla
  // pegada a un comentario deja de ser una regla.
  final separator = existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
  await file.writeAsString(
    '$existing$separator$_roadmapIgnoreBlock',
    mode: FileMode.write,
  );
  return true;
}

bool _isGitRepository(String root) =>
    Directory('$root/.git').existsSync() || File('$root/.git').existsSync();

/// Si alguna línea del `.gitignore` ya deja `TASKS/` afuera.
///
/// Se aceptan las formas equivalentes que escribe la gente —`TASKS`,
/// `TASKS/`, `/TASKS/`, `TASKS/**`— y se ignoran los comentarios. Un patrón
/// más raro que eso no se intenta interpretar: en el peor caso queda una
/// línea repetida, que es inofensiva, y no un `.gitignore` mal leído.
bool _alreadyIgnoresRoadmap(String contents) {
  for (final raw in contents.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final normalized = line
        .replaceAll(RegExp(r'^/'), '')
        .replaceAll(RegExp(r'/?(\*\*)?/?$'), '');
    if (normalized == kRoadmapFolder) return true;
  }
  return false;
}
