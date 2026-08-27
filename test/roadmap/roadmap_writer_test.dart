import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';

void main() {
  late Directory project;
  late Directory grupo;

  setUp(() {
    project = Directory.systemTemp.createTempSync('keel_writer');
    grupo = Directory('${project.path}/TASKS/02-matriculas')
      ..createSync(recursive: true);
    File('${project.path}/TASKS/README.md').writeAsStringSync('# Objetivo\n');
    File('${grupo.path}/README.md').writeAsStringSync('# Matrículas\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  RoadmapWriteResult escribir({
    String folder = '02-matriculas',
    String title = 'CRUD de personal',
    RoadmapPriority priority = RoadmapPriority.alta,
    String detail = 'Endpoints bajo /school/institutions/{id}/staff.',
    List<String> blockers = const [],
  }) => writeRoadmapTask(
    projectPath: project.path,
    folder: folder,
    title: title,
    priority: priority,
    detail: detail,
    blockers: blockers,
    origin: 'el requerimiento REQ-0003 de "aulamas-portal"',
  );

  group('el número', () {
    test('la primera de un grupo vacío es la 01', () {
      expect(escribir().path, '02-matriculas/01-crud-de-personal.md');
    });

    test('sigue al mayor que ya está', () {
      File('${grupo.path}/01-listado.md').writeAsStringSync('---\n---\n');
      File('${grupo.path}/07-alta.md').writeAsStringSync('---\n---\n');

      expect(escribir().path, '02-matriculas/08-crud-de-personal.md');
    });

    test('no reusa el hueco de una que se borró', () {
      File('${grupo.path}/03-algo.md').writeAsStringSync('---\n---\n');

      // Reusar el 02 sería reusar el lugar de algo que se decidió sacar.
      expect(escribir().path, '02-matriculas/04-crud-de-personal.md');
    });

    test('el README del grupo no cuenta como tarea', () {
      expect(escribir().path, startsWith('02-matriculas/01-'));
    });

    test('no pisa un archivo que ya existe', () {
      File(
        '${grupo.path}/01-crud-de-personal.md',
      ).writeAsStringSync('la de otro\n');

      final segunda = writeRoadmapTask(
        projectPath: project.path,
        folder: '02-matriculas',
        title: 'CRUD de personal',
        priority: RoadmapPriority.alta,
        detail: 'x',
      );

      // El número la esquiva sola; y si aun así colisionara, no escribe.
      expect(segunda.path, isNot('02-matriculas/01-crud-de-personal.md'));
      expect(
        File('${grupo.path}/01-crud-de-personal.md').readAsStringSync(),
        'la de otro\n',
      );
    });
  });

  group('el nombre', () {
    test('sale del título, sin acentos ni espacios', () {
      final escrita = escribir(title: 'Migración de Matrículas ÑOÑAS');

      expect(escrita.path, '02-matriculas/01-migracion-de-matriculas-nonas.md');
    });

    test('un título imposible igual da un nombre usable', () {
      expect(escribir(title: '¿¡...!?').path, '02-matriculas/01-tarea.md');
    });

    test('un título larguísimo se corta sin dejar el guion colgando', () {
      final escrita = escribir(title: 'a' * 80);
      final nombre = escrita.path!.split('/').last;

      expect(nombre.length, lessThanOrEqualTo(56));
      expect(nombre, isNot(contains('-.md')));
    });
  });

  group('lo que escribe se puede volver a leer', () {
    test('el lector lo entiende entero', () {
      final escrita = escribir(priority: RoadmapPriority.alta);
      final tarea = parseRoadmapTask(
        escrita.path!,
        File('${project.path}/TASKS/${escrita.path}').readAsStringSync(),
      );

      expect(tarea.title, 'CRUD de personal');
      expect(tarea.state, RoadmapState.libre);
      expect(tarea.declaresState, isTrue);
      expect(tarea.priority, RoadmapPriority.alta);
      expect(tarea.declaresPriority, isTrue);
      expect(tarea.isDraft, isFalse);
      expect(tarea.isTakeable, isTrue);
    });

    test('y la carpeta sigue pasando el chequeo de formato', () {
      escribir();

      final check = checkRoadmapFormat(project.path);
      expect(check.ok, isTrue, reason: check.findings.join(' · '));
    });

    test('deja dicho de qué requerimiento salió', () {
      final escrita = escribir();
      final texto = File(
        '${project.path}/TASKS/${escrita.path}',
      ).readAsStringSync();

      expect(texto, contains('REQ-0003'));
    });

    test('un bloqueante sin justificación no se inventa: se marca', () {
      final escrita = escribir(blockers: const ['01-otra.md']);
      final texto = File(
        '${project.path}/TASKS/${escrita.path}',
      ).readAsStringSync();

      expect(texto, contains('- [ ] 01-otra.md — falta decir por qué bloquea'));
    });

    test('y uno con justificación se respeta tal cual', () {
      final escrita = escribir(
        blockers: const ['01-otra.md — sin eso no hay dónde apoyarlo'],
      );
      final tarea = parseRoadmapTask(
        escrita.path!,
        File('${project.path}/TASKS/${escrita.path}').readAsStringSync(),
      );

      expect(tarea.blockers, hasLength(1));
      expect(tarea.hasOpenBlockers, isTrue);
    });
  });

  group('lo que se niega a hacer', () {
    test('no crea el grupo que falta, y dice cuáles hay', () {
      final fallo = escribir(folder: '09-inventado');

      expect(fallo.path, isNull);
      expect(fallo.error, contains('09-inventado'));
      expect(fallo.error, contains('02-matriculas'));
      expect(
        Directory('${project.path}/TASKS/09-inventado').existsSync(),
        isFalse,
        reason: 'un grupo sin README rompe el chequeo de formato',
      );
    });

    test('no acepta grupos anidados ni escapes', () {
      for (final folder in ['02-matriculas/adentro', '../afuera']) {
        expect(escribir(folder: folder).path, isNull, reason: folder);
      }
    });

    test('sin título no escribe nada', () {
      expect(escribir(title: '   ').path, isNull);
    });
  });
}
