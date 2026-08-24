import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';

void main() {
  test('una causa concreta suprime la atribución genérica al proveedor', () {
    final completed =
        TaskEvent.fromMessage({
              'type': 'turnCompleted',
              'isError': true,
              'hasReportedFailure': true,
              'costUsd': 0.0,
              'durationMs': 1,
              'model': 'openai/gpt-4',
            })
            as TaskTurnCompleted;

    expect(completed.hasReportedFailure, isTrue);
    expect(completed.needsProviderFailureFallback, isFalse);
  });

  test('sin detalle conserva el fallback del proveedor', () {
    final completed =
        TaskEvent.fromMessage({
              'type': 'turnCompleted',
              'isError': true,
              'costUsd': 0.0,
              'durationMs': 1,
              'model': 'openai/gpt-4',
            })
            as TaskTurnCompleted;

    expect(completed.hasReportedFailure, isFalse);
    expect(completed.needsProviderFailureFallback, isTrue);
  });
}
