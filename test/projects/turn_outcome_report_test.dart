import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';

void main() {
  group('parseKeelOutcome', () {
    test('lee un bloque embebido en prosa, con NO-GO y sin next', () {
      const text = '''
Revisé el diff completo. Hay un `unwrap()` en producción.

```keel-outcome
status: done
summary: Un unwrap en lib/a.dart:12 y un test sin oráculo.
  El resto cumple el contrato.
files: lib/a.dart, test/a_test.dart
artifacts: informe en progress/audit.md
verdict: NO-GO
```

Eso es todo.
''';

      final report = parseKeelOutcome(text);

      expect(report, isNotNull);
      expect(report!.status, TurnOutcomeStatus.done);
      expect(report.verdict, TurnVerdict.noGo);
      expect(report.summary, contains('unwrap'));
      expect(report.summary, contains('cumple el contrato'));
      expect(report.files, ['lib/a.dart', 'test/a_test.dart']);
      expect(report.artifacts, 'informe en progress/audit.md');
      expect(report.next, isEmpty);
      expect(report.question, isEmpty);
    });

    test('con dos bloques gana el último: el modelo corrige sobre la marcha',
        () {
      const text = '''
```keel-outcome
status: blocked
summary: no compila
```
Arreglé el import.
```keel-outcome
status: done
summary: compila y los tests pasan
```
''';

      expect(parseKeelOutcome(text)!.status, TurnOutcomeStatus.done);
    });

    test('needs_user trae la pregunta y acepta variantes del estado', () {
      const text = '''
```keel-outcome
status: NEEDS_USER
summary: falta decidir el nombre de la tabla
question: ¿la tabla se llama `orders` u `order_items`?
```
''';

      final report = parseKeelOutcome(text)!;

      expect(report.status, TurnOutcomeStatus.needsUser);
      expect(report.question, contains('orders'));
    });

    test('sin bloque devuelve null; con estado inválido también', () {
      expect(parseKeelOutcome('trabajé y listo'), isNull);
      expect(
        parseKeelOutcome('```keel-outcome\nstatus: maybe\n```'),
        isNull,
      );
    });

    test('sobrevive al disco', () {
      const report = TurnOutcomeReport(
        status: TurnOutcomeStatus.needsPermission,
        summary: 'necesito git push',
        files: ['lib/x.dart'],
        artifacts: 'PR pendiente',
        verdict: TurnVerdict.go,
        next: 'e2e-real',
        question: '¿puedo pushear?',
      );

      expect(TurnOutcomeReport.fromJson(report.toJson()), report);
    });
  });
}
