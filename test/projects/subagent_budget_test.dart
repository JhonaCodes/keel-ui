import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/service/subagent_budget.dart';

void main() {
  test('rechaza el primer subagente cuando el máximo es cero', () {
    final budget = SubagentBudget();

    expect(budget.tryReserve(turnId: 'root', maxSubagents: 0), isFalse);
  });

  test('acepta dos subagentes y rechaza el tercero del mismo root', () {
    final budget = SubagentBudget();

    expect(budget.tryReserve(turnId: 'root', maxSubagents: 2), isTrue);
    expect(budget.tryReserve(turnId: 'root', maxSubagents: 2), isTrue);
    expect(budget.tryReserve(turnId: 'root', maxSubagents: 2), isFalse);
  });

  test(
    'comparte el límite por root, pero un mensaje nuevo empieza en cero',
    () {
      final budget = SubagentBudget();

      expect(budget.tryReserve(turnId: 'root', maxSubagents: 1), isTrue);
      expect(budget.tryReserve(turnId: 'root', maxSubagents: 1), isFalse);
      expect(budget.tryReserve(turnId: 'other-root', maxSubagents: 1), isTrue);
    },
  );
}
