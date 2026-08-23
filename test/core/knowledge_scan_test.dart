import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

Directory _base() {
  final dir = Directory.systemTemp.createTempSync('keel-saber-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void main() {
  group('el árbol de una base se arma en otro isolate', () {
    test('el resultado cruza la frontera entero', () async {
      final base = _base();
      File('${base.path}/README.md').writeAsStringSync('# La portada');
      Directory('${base.path}/guias').createSync();
      File('${base.path}/guias/uno.md').writeAsStringSync('uno');
      File('${base.path}/guias/dos.md').writeAsStringSync('dos');

      // Lo que importa: que `KnowledgeScan` —con su árbol anidado— sea
      // enviable. Si no lo fuera, esto explotaría recién cuando alguien
      // toque «Actualizar».
      final scan = await Isolate.run(() => scanKnowledgeTree(base.path));

      expect(scan.indexContent, '# La portada');
      expect(scan.truncated, isFalse);
      // Carpetas primero, después archivos, y cada una alfabética.
      expect(scan.nodes.map((node) => node.name), ['guias', 'README.md']);
      final guias = scan.nodes.first;
      expect(guias.isDirectory, isTrue);
      expect(guias.children.map((node) => node.name), ['dos.md', 'uno.md']);
      expect(guias.children.first.relativePath, 'guias/dos.md');
    });

    test('los ocultos y las carpetas de siempre quedan afuera', () {
      final base = _base();
      File('${base.path}/visible.md').writeAsStringSync('ok');
      File('${base.path}/.oculto').writeAsStringSync('no');
      Directory('${base.path}/.git').createSync();
      File('${base.path}/.git/config').writeAsStringSync('no');
      Directory('${base.path}/node_modules').createSync();
      File('${base.path}/node_modules/x.js').writeAsStringSync('no');

      final scan = scanKnowledgeTree(base.path);
      expect(scan.nodes.map((node) => node.name), ['visible.md']);
    });

    test('una carpeta que queda vacía tras el filtro no se lista', () {
      final base = _base();
      Directory('${base.path}/solo-ocultos').createSync();
      File('${base.path}/solo-ocultos/.env').writeAsStringSync('x');

      expect(scanKnowledgeTree(base.path).nodes, isEmpty);
    });

    test('sin portada, la portada es vacía y no un error', () {
      final base = _base();
      File('${base.path}/algo.md').writeAsStringSync('x');
      expect(scanKnowledgeTree(base.path).indexContent, '');
    });
  });
}
