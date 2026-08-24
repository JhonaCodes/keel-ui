import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/code_block_presentation.dart';

void main() {
  test('todos los bloques declarativos de Keel se convierten a markdown', () {
    for (final fence in const [
      'agente',
      'cobertura',
      'cumplido',
      'estacion',
      'plan',
      'proyecto',
      'regla',
      'skill',
      'workflow',
    ]) {
      final presentation = CodeBlockPresentation.from(
        fenceName: fence,
        source: 'nombre: ejemplo\nreglas: una, dos',
      );

      expect(presentation.rendersMarkdown, isTrue, reason: fence);
      expect(presentation.language, 'markdown', reason: fence);
      expect(presentation.source, contains('## ejemplo'), reason: fence);
      expect(presentation.source, contains('- `una`\n- `dos`'), reason: fence);
    }
  });

  test('texto y markdown se leen como documentos', () {
    for (final fence in const ['text', 'plaintext', 'md', 'markdown']) {
      final presentation = CodeBlockPresentation.from(
        fenceName: fence,
        source: '# Título\n\nContenido',
      );

      expect(presentation.rendersMarkdown, isTrue, reason: fence);
      expect(presentation.source, '# Título\n\nContenido', reason: fence);
    }
  });

  test('código conserva su fuente y normaliza el lenguaje', () {
    final presentation = CodeBlockPresentation.from(
      fenceName: 'ts',
      source: 'const answer: number = 42;',
    );

    expect(presentation.rendersMarkdown, isFalse);
    expect(presentation.language, 'typescript');
    expect(presentation.source, 'const answer: number = 42;');
  });

  test('capacidades de workflow se muestran con jerarquía legible', () {
    final presentation = CodeBlockPresentation.from(
      fenceName: 'workflow',
      source:
          'nombre: tdd\n'
          'capacidades: diagnose|Diagnosticar|resolver|required||Aislar causa ;; '
          'verify|Verificar|tester|optional|diagnose|Correr regresión',
    );

    expect(presentation.source, contains('1. **Diagnosticar** · `required`'));
    expect(presentation.source, contains('Rol: `resolver`'));
    expect(presentation.source, contains('Depende de: diagnose'));
  });
}
