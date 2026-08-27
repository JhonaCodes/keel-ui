import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';

final _epoch = DateTime.utc(2026, 8, 27);

void main() {
  LocalDatabase.markUnavailable();

  Session unaSesion({
    bool planMode = false,
    bool planAwaitingDecision = false,
  }) => Session(
    id: 's1',
    title: 'Sesión',
    createdAt: _epoch,
    request: 'Arreglar el login',
    workflowId: 'w1',
    planMode: planMode,
    planAwaitingDecision: planAwaitingDecision,
    messages: const [],
  );

  group('el modo plan de una sesión', () {
    test('el modo se guarda, la tarjeta no', () {
      // El modo es una decisión del usuario sobre la sesión; la tarjeta es
      // una pregunta en pantalla. Nadie quiere reabrir la app y encontrar
      // una pregunta sobre un plan que ya no recuerda.
      final ida = Session.fromJson(
        unaSesion(planMode: true, planAwaitingDecision: true).toJson(),
      );

      expect(ida.planMode, isTrue);
      expect(ida.planAwaitingDecision, isFalse);
    });

    test('una sesión guardada antes de esto se lee apagada', () {
      final json = unaSesion().toJson()..remove('planMode');

      expect(Session.fromJson(json).planMode, isFalse);
    });

    test('cambiar el modo cambia la identidad de la sesión', () {
      // `_updateSession` no notifica si el estado sale igual: sin esto en
      // `==`, prender el modo plan no repintaría la pantalla.
      expect(unaSesion(planMode: true), isNot(unaSesion()));
      expect(unaSesion(planAwaitingDecision: true), isNot(unaSesion()));
    });

    test('y también su hashCode', () {
      expect(unaSesion(planMode: true).hashCode, isNot(unaSesion().hashCode));
    });

    test('copyWith conserva el modo cuando no se lo nombra', () {
      final copia = unaSesion(
        planMode: true,
      ).copyWith(messages: const <ChatMessage>[]);

      expect(copia.planMode, isTrue);
    });
  });
}
