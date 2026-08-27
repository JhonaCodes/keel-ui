import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';

String _tarea({String? prioridad}) =>
    [
      '---',
      'estado: libre',
      if (prioridad != null) 'prioridad: $prioridad',
      'titulo: Capa de dispositivo',
      '---',
      '',
      '# Capa de dispositivo',
    ].join('\n');

void main() {
  group('leer la prioridad', () {
    test('se lee la que declara el archivo', () {
      for (final (texto, esperada) in [
        ('alta', RoadmapPriority.alta),
        ('media', RoadmapPriority.media),
        ('baja', RoadmapPriority.baja),
      ]) {
        final tarea = parseRoadmapTask('01-g/01-t.md', _tarea(prioridad: texto));
        expect(tarea.priority, esperada);
        expect(tarea.declaresPriority, isTrue);
      }
    });

    test('no declararla no es lo mismo que declarar media', () {
      final callada = parseRoadmapTask('01-g/01-t.md', _tarea());
      final dicha = parseRoadmapTask('01-g/01-t.md', _tarea(prioridad: 'media'));

      expect(callada.priority, RoadmapPriority.media);
      expect(callada.declaresPriority, isFalse);
      expect(dicha.declaresPriority, isTrue);
    });

    test('mayúsculas y espacios no importan', () {
      final tarea = parseRoadmapTask('01-g/01-t.md', _tarea(prioridad: '  ALTA '));

      expect(tarea.priority, RoadmapPriority.alta);
    });

    test('una prioridad inventada cae en media y no rompe nada', () {
      final tarea = parseRoadmapTask(
        '01-g/01-t.md',
        _tarea(prioridad: 'urgentísima'),
      );

      expect(tarea.priority, RoadmapPriority.media);
      expect(tarea.title, 'Capa de dispositivo');
      expect(tarea.state, RoadmapState.libre);
      expect(
        tarea.isTakeable,
        isTrue,
        reason: 'una prioridad mal escrita no puede sacar la tarea de la fila',
      );
    });
  });

  group('las carpetas que ya existen', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('keel_prio');
      final tasks = Directory('${project.path}/TASKS/01-fundacion')
        ..createSync(recursive: true);
      File('${project.path}/TASKS/README.md').writeAsStringSync('# Objetivo\n');
      File('${tasks.path}/README.md').writeAsStringSync('# Fundación\n');
      File('${tasks.path}/01-shell.md').writeAsStringSync(_tarea());
    });

    tearDown(() => project.deleteSync(recursive: true));

    test('un TASKS/ sin ninguna prioridad sigue pasando el chequeo', () {
      final check = checkRoadmapFormat(project.path);

      expect(
        check.ok,
        isTrue,
        reason: 'la prioridad es opcional: hacerla obligatoria invalidaría '
            'de golpe todos los roadmaps que ya existen',
      );
      expect(check.findings, isEmpty);
    });

    test('y agregarle prioridad a una tarea tampoco lo rompe', () {
      File(
        '${project.path}/TASKS/01-fundacion/01-shell.md',
      ).writeAsStringSync(_tarea(prioridad: 'alta'));

      final check = checkRoadmapFormat(project.path);

      expect(check.ok, isTrue);
      expect(readRoadmap(project.path).single.priority, RoadmapPriority.alta);
    });
  });
}
