part of '../roadmap_mcp.dart';

/// Qué tan mal está: lo que falta del todo, y lo que está pero mal escrito.
enum FormatFindingLevel { falta, mal }

/// Una cosa concreta que hay que arreglar, nombrada.
///
/// Un booleano no sirve acá: "el formato no cierra" no le dice a nadie qué
/// hacer, y esta misma lista es la que después se le pasa al agente que lo
/// arregla.
class FormatFinding {
  const FormatFinding(this.level, this.message, {this.where});

  final FormatFindingLevel level;
  final String message;

  /// El archivo o la carpeta, relativo a la raíz del repo.
  final String? where;

  @override
  String toString() => where == null ? message : '$where — $message';
}

/// El resultado del chequeo, con lo que pasó y lo que no.
class RoadmapFormatCheck {
  const RoadmapFormatCheck({
    required this.passed,
    required this.findings,
    required this.taskCount,
  });

  /// Lo que sí está bien, en el orden en que se chequea. Se muestra junto a
  /// lo que falta: una lista de puros errores no deja ver cuánto se avanzó.
  final List<String> passed;
  final List<FormatFinding> findings;
  final int taskCount;

  bool get ok => findings.isEmpty && taskCount > 0;
  int get total => passed.length + findings.length;
}

/// Chequea que la carpeta de tareas del proyecto tenga la forma acordada.
///
/// Es lo mismo que corre solo al cerrar la sesión que la arma: pedir por
/// prompt que el agente verifique su propio trabajo es pedir, no garantizar.
RoadmapFormatCheck checkRoadmapFormat(String projectPath) {
  final passed = <String>[];
  final findings = <FormatFinding>[];

  final root = projectPath.trim();
  if (root.isEmpty) {
    return const RoadmapFormatCheck(
      passed: [],
      findings: [
        FormatFinding(
          FormatFindingLevel.falta,
          'El proyecto todavía no tiene carpeta de trabajo elegida.',
        ),
      ],
      taskCount: 0,
    );
  }

  final tasksDir = Directory('$root/$kRoadmapFolder');
  if (!tasksDir.existsSync()) {
    return RoadmapFormatCheck(
      passed: passed,
      findings: [
        const FormatFinding(
          FormatFindingLevel.falta,
          'No existe la carpeta $kRoadmapFolder/ en la raíz del repo.',
          where: '$kRoadmapFolder/',
        ),
      ],
      taskCount: 0,
    );
  }
  passed.add('$kRoadmapFolder/ está en la raíz del repo');

  if (File('${tasksDir.path}/README.md').existsSync()) {
    passed.add('README raíz con el objetivo final');
  } else {
    findings.add(
      const FormatFinding(
        FormatFindingLevel.falta,
        'Falta el README con el objetivo final del proyecto.',
        where: '$kRoadmapFolder/README.md',
      ),
    );
  }

  // Una tarea suelta en la raíz no la lee nadie: el lector solo baja a las
  // carpetas de grupo, así que estaría escrita y sería invisible.
  final loose = tasksDir
      .listSync()
      .whereType<File>()
      .where(
        (file) =>
            file.path.toLowerCase().endsWith('.md') &&
            !file.path.split('/').last.toLowerCase().startsWith('readme'),
      )
      .toList();
  if (loose.isEmpty) {
    passed.add('Ninguna tarea suelta en la raíz');
  } else {
    for (final file in loose) {
      findings.add(
        FormatFinding(
          FormatFindingLevel.mal,
          'Una tarea vive dentro de una carpeta de grupo, no en la raíz.',
          where: '$kRoadmapFolder/${file.path.split('/').last}',
        ),
      );
    }
  }

  final groups = tasksDir
      .listSync()
      .whereType<Directory>()
      .where((dir) => !dir.path.split('/').last.startsWith('.'))
      .toList();
  if (groups.isEmpty) {
    findings.add(
      const FormatFinding(
        FormatFindingLevel.falta,
        'No hay ninguna carpeta de grupo (por ejemplo 01-fundacion).',
        where: '$kRoadmapFolder/',
      ),
    );
  } else {
    final sinReadme = groups
        .where((dir) => !File('${dir.path}/README.md').existsSync())
        .toList();
    if (sinReadme.isEmpty) {
      passed.add('${groups.length} carpetas de grupo, todas con README');
    } else {
      for (final dir in sinReadme) {
        final name = dir.path.split('/').last;
        // Los borradores son salida cruda esperando al estandarizador: no se
        // les exige nada todavía.
        if (name.startsWith('_')) continue;
        findings.add(
          FormatFinding(
            FormatFindingLevel.falta,
            'Al grupo le falta su README con el objetivo del grupo.',
            where: '$kRoadmapFolder/$name/README.md',
          ),
        );
      }
    }
  }

  final tasks = readRoadmap(root);
  final reales = tasks.where((task) => !task.isDraft).toList();
  if (reales.isEmpty) {
    findings.add(
      const FormatFinding(
        FormatFindingLevel.falta,
        'No hay ninguna tarea todavía.',
        where: '$kRoadmapFolder/',
      ),
    );
  } else {
    passed.add('${reales.length} tareas, todas dentro de un grupo');
  }

  final sinEstado = reales.where((task) => !task.declaresState).toList();
  if (sinEstado.isEmpty && reales.isNotEmpty) {
    passed.add('Todos los frontmatter parsean');
  }
  for (final task in sinEstado) {
    findings.add(
      FormatFinding(
        FormatFindingLevel.mal,
        'No declara "estado:" en el frontmatter.',
        where: '$kRoadmapFolder/${task.path}',
      ),
    );
  }

  final rotas = [
    for (final task in tasks)
      for (final blocker in task.brokenBlockers) (task: task, blocker: blocker),
  ];
  if (rotas.isEmpty && reales.isNotEmpty) {
    passed.add('Ninguna referencia rota entre tareas');
  }
  for (final rota in rotas) {
    findings.add(
      FormatFinding(
        FormatFindingLevel.mal,
        rota.blocker.target == BlockerTarget.missing
            ? 'Apunta a "${rota.blocker.reference}", que no existe.'
            : 'Apunta a "${rota.blocker.reference}", que existe en dos carpetas.',
        where: '$kRoadmapFolder/${rota.task.path}',
      ),
    );
  }

  return RoadmapFormatCheck(
    passed: passed,
    findings: findings,
    taskCount: reales.length,
  );
}
