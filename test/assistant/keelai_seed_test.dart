import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/assistant/model/keelai_seed.dart';

void main() {
  test('Keel AI reasons from the live generic adaptive architecture', () {
    expect(kKeelAiSystemPrompt, contains('fuente de verdad'));
    expect(kKeelAiSystemPrompt, contains('transacción de catálogo'));
    expect(kKeelAiSystemPrompt, contains('`list_workflows`'));
    expect(kKeelAiSystemPrompt, contains('`list_projects`'));
    expect(kKeelAiSystemPrompt, contains('TODOS los contratos de workflow'));
    expect(kKeelAiSystemPrompt, contains('independent'));
    expect(kKeelAiSystemPrompt, contains('node_assignments'));
    expect(kKeelAiSystemPrompt, isNot(contains('UN PROYECTO POR STACK')));
    expect(
      kKeelAiSystemPrompt,
      contains('No agregues planificador, diagnosticador, revisor'),
    );
    expect(
      kKeelAiSystemPrompt,
      contains('Keel no está condicionado a Flutter, Rust'),
    );
  });
}
