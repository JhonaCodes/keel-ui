import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/service/subagent_budget.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

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

  test('un nodo no le consume el presupuesto al siguiente', () {
    final budget = SubagentBudget();

    // El nodo del charter agota su cupo...
    expect(
      budget.tryReserve(
        turnId: 'root',
        workNodeId: 'charter',
        maxSubagents: 1,
      ),
      isTrue,
    );
    expect(
      budget.tryReserve(
        turnId: 'root',
        workNodeId: 'charter',
        maxSubagents: 1,
      ),
      isFalse,
    );

    // ...y el de implementar arranca entero, en la MISMA corrida.
    expect(
      budget.tryReserve(
        turnId: 'root',
        workNodeId: 'implementar',
        maxSubagents: 1,
      ),
      isTrue,
    );
  });

  test('sin nodo el alcance sigue siendo el turno — el caso del chat 1:1', () {
    final budget = SubagentBudget();

    expect(budget.tryReserve(turnId: 'root', maxSubagents: 1), isTrue);
    expect(
      budget.tryReserve(turnId: 'root', workNodeId: '', maxSubagents: 1),
      isFalse,
    );
  });

  test('acepta seis en el mismo nodo y rechaza el séptimo', () {
    final budget = SubagentBudget();

    for (var i = 0; i < kMaxSubagentsPerNode; i++) {
      expect(
        budget.tryReserve(
          turnId: 'root',
          workNodeId: 'auditar',
          maxSubagents: kMaxSubagentsPerNode,
        ),
        isTrue,
        reason: 'el subagente ${i + 1} tiene que entrar',
      );
    }
    expect(
      budget.tryReserve(
        turnId: 'root',
        workNodeId: 'auditar',
        maxSubagents: kMaxSubagentsPerNode,
      ),
      isFalse,
    );
  });
}
