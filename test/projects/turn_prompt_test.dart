import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/service/turn_prompt.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';

void main() {
  test('una skill del workflow se compone una sola vez', () {
    final skill = Skill(
      id: 'workflow-skill',
      name: 'workflow-skill',
      content: 'MARCADOR-WORKFLOW',
      createdAt: DateTime.utc(2026),
    );

    final selected = assignedNonGlobalSkills(
      [skill],
      ['workflow-skill', 'workflow-skill'],
    );

    expect(
      selected.map((entry) => entry.content).join('\n'),
      'MARCADOR-WORKFLOW',
    );
  });

  test('saber y plan quedan después del contenido estable', () {
    final prompt = composeTurnSystemPrompt(
      stablePrompt: 'ENTREGA-ESTABLE\nPOLICY-ESTABLE',
      knowledge: 'SABER-DINAMICO',
      plan: 'PLAN-DINAMICO',
    );

    expect(
      prompt.indexOf('ENTREGA-ESTABLE'),
      lessThan(prompt.indexOf('SABER-DINAMICO')),
    );
    expect(
      prompt.indexOf('SABER-DINAMICO'),
      lessThan(prompt.indexOf('PLAN-DINAMICO')),
    );
  });

  test('el ensamblado conserva el saber cuando no hay plan', () {
    final prompt = composeTurnSystemPrompt(
      stablePrompt: 'ESTABLE',
      knowledge: 'SABER-DINAMICO',
    );

    expect(prompt, contains('SABER-DINAMICO'));
    expect(prompt, isNot(contains('PLAN-DINAMICO')));
  });

  group('budgetTurnSystemPrompt', () {
    const sections = [
      PromptSection(name: 'skill-global', text: 'GLOBAL-1', dropPriority: 1),
      PromptSection(name: 'identidad', text: 'IDENTIDAD'),
      PromptSection(name: 'skill-asignada', text: 'ASIGNADA', dropPriority: 2),
      PromptSection(name: 'reglas', text: 'REGLA-MARCADOR'),
      PromptSection(name: 'saber', text: 'SABER-BRIEF', dropPriority: 3),
    ];

    test('con presupuesto de sobra no recorta nada', () {
      final budgeted = budgetTurnSystemPrompt(sections, maxChars: 10000);

      expect(budgeted.dropped, isEmpty);
      expect(budgeted.text, contains('SABER-BRIEF'));
    });

    test('recorta primero el saber, después las skills; las reglas y la '
        'identidad nunca', () {
      final total = sections.fold<int>(0, (sum, s) => sum + s.text.length);
      final budgeted = budgetTurnSystemPrompt(sections, maxChars: total - 1);

      expect(budgeted.dropped, ['saber']);
      expect(budgeted.text, contains('REGLA-MARCADOR'));
      expect(budgeted.text, isNot(contains('SABER-BRIEF')));

      final tight = budgetTurnSystemPrompt(sections, maxChars: 30);
      expect(tight.dropped, ['saber', 'skill-asignada', 'skill-global']);
      expect(tight.text, contains('REGLA-MARCADOR'));
      expect(tight.text, contains('IDENTIDAD'));
    });
  });

}
