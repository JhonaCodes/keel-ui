part of '../roadmap_mcp.dart';

/// Cómo salió de escribir una tarea: la ruta relativa, o por qué no se pudo.
typedef RoadmapWriteResult = ({String? path, String? error});

/// Escribe una tarea nueva en `TASKS/<folder>/`, con el formato exacto que
/// [parseRoadmapTask] sabe leer.
///
/// **Es lo único de la app que escribe un `.md` de tarea.** Hasta acá los
/// escribían solo los agentes con sus tools de archivo, y está bien que así
/// sea para el trabajo que ellos descubren. Pero un requerimiento aceptado no
/// es trabajo descubierto: es un acuerdo que ya se cerró, y lo que falta es
/// anotarlo sin errores.
///
/// Lo que hace esta función y un agente hace mal:
///
/// - **El número.** Toma el siguiente libre de la carpeta. Un agente numera
///   pisando un archivo que ya está, o deja huecos, o —peor— usa el mismo
///   número dos veces y el orden deja de significar algo.
/// - **El nombre.** Del título sale un slug con lo que un nombre de archivo
///   soporta, sin acentos ni espacios.
/// - **El formato.** Frontmatter plano, sección de bloqueantes, criterio de
///   aceptación: exactamente lo que el lector espera.
///
/// [folder] tiene que existir. Crearla acá sería crear un grupo sin
/// `README.md`, que es justo uno de los nueve puntos que
/// [checkRoadmapFormat] mira — la tool escribiría una tarea y rompería la
/// carpeta en el mismo movimiento. Elegir el grupo es un juicio sobre el
/// roadmap, y ese juicio es del agente.
RoadmapWriteResult writeRoadmapTask({
  required String projectPath,
  required String folder,
  required String title,
  required RoadmapPriority priority,
  required String detail,
  List<String> blockers = const [],
  String? origin,
}) {
  final cleanFolder = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  if (cleanFolder.isEmpty) return (path: null, error: 'Falta la carpeta.');
  if (cleanFolder.contains('/') || cleanFolder.contains('..')) {
    return (
      path: null,
      error:
          'La carpeta es un grupo de primer nivel: "$cleanFolder" no lo es. '
          'Los grupos no se anidan.',
    );
  }
  if (title.trim().isEmpty) return (path: null, error: 'Falta el título.');

  final group = Directory('$projectPath/$kRoadmapFolder/$cleanFolder');
  if (!group.existsSync()) {
    final existing = _groupNames(projectPath);
    return (
      path: null,
      error:
          'No existe el grupo "$cleanFolder" en $kRoadmapFolder/. '
          '${existing.isEmpty ? 'Todavía no hay ninguno.' : 'Los que hay: ${existing.join(', ')}.'} '
          'Elegí uno, o creá el grupo con su README.md antes de convertir.',
    );
  }

  final slug = _slug(title);
  final number = _nextNumber(group).toString().padLeft(2, '0');
  final name = '$number-$slug.md';
  final file = File('${group.path}/$name');
  // No debería pasar —el número sale de mirar la carpeta— pero escribir
  // encima de una tarea ajena es la clase de error que no se perdona.
  if (file.existsSync()) {
    return (path: null, error: 'Ya existe $cleanFolder/$name.');
  }

  file.writeAsStringSync(
    _taskFile(
      title: title.trim(),
      priority: priority,
      detail: detail.trim(),
      blockers: blockers,
      origin: origin,
    ),
  );
  return (path: '$cleanFolder/$name', error: null);
}

String _taskFile({
  required String title,
  required RoadmapPriority priority,
  required String detail,
  required List<String> blockers,
  required String? origin,
}) {
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('estado: libre')
    ..writeln('prioridad: ${priority.alias}')
    ..writeln('titulo: $title')
    ..writeln('---')
    ..writeln()
    ..writeln('# $title')
    ..writeln();
  if (origin != null && origin.trim().isNotEmpty) {
    buffer
      ..writeln('> Sale de ${origin.trim()}.')
      ..writeln();
  }
  buffer
    ..writeln('## Qué hay que hacer')
    ..writeln()
    ..writeln(detail.isEmpty ? 'Sin detalle.' : detail)
    ..writeln()
    ..writeln('## Bloqueantes')
    ..writeln();
  if (blockers.isEmpty) {
    buffer.writeln('Ninguno.');
  } else {
    for (final blocker in blockers) {
      final line = blocker.trim();
      if (line.isEmpty) continue;
      // La justificación es obligatoria en el formato: sin ella nadie sabe
      // si el bloqueo sigue vigente. Si el agente no la escribió, se deja
      // dicho que falta en vez de inventarla.
      buffer.writeln(
        line.contains('—') || line.contains('--')
            ? '- [ ] $line'
            : '- [ ] $line — falta decir por qué bloquea',
      );
    }
  }
  buffer
    ..writeln()
    ..writeln('## Criterio de aceptación')
    ..writeln()
    ..writeln('- [ ] ');
  return buffer.toString();
}

/// El siguiente número libre de la carpeta.
///
/// Mira los `NN-` que ya están y devuelve el que sigue al mayor. No busca
/// huecos: si alguien borró la 02, la próxima sigue siendo la 05 y no la 02
/// — reusar un número es reusar el lugar de algo que se decidió sacar.
int _nextNumber(Directory group) {
  var highest = 0;
  for (final entity in group.listSync(followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final name = entity.path.split('/').last;
    if (name.toUpperCase() == 'README.MD') continue;
    final match = RegExp(r'^(\d+)').firstMatch(name);
    final number = int.tryParse(match?.group(1) ?? '') ?? 0;
    if (number > highest) highest = number;
  }
  return highest + 1;
}

List<String> _groupNames(String projectPath) {
  final root = Directory('$projectPath/$kRoadmapFolder');
  if (!root.existsSync()) return const [];
  return [
    for (final entity in root.listSync(followLinks: false))
      if (entity is Directory) entity.path.split('/').last,
  ]..sort();
}

/// Un título convertido en algo que soporta un nombre de archivo.
String _slug(String title) {
  const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = title.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final at = accents.indexOf(char);
    buffer.write(at >= 0 ? plain[at] : char);
  }
  final slug = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'tarea';
  return slug.length <= 48
      ? slug
      : slug.substring(0, 48).replaceAll(RegExp(r'-+$'), '');
}
