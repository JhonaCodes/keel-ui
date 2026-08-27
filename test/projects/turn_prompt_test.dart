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
}
