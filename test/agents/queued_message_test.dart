import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/queued_message.dart';

void main() {
  group('el modelo de la cola', () {
    test('cada mensaje nace con identidad propia', () {
      // Editar o borrar una fila no puede depender de un índice: mientras la
      // tarjeta está abierta puede terminar un turno y mover la cola.
      final uno = QueuedMessage(text: 'a');
      final otro = QueuedMessage(text: 'a');

      expect(uno.id, isNotEmpty);
      expect(uno.id, isNot(otro.id));
    });

    test('arranca en espera', () {
      expect(QueuedMessage(text: 'a').delivery, QueuedDelivery.standby);
    });

    test('sobrevive el viaje por el puente', () {
      final original = QueuedMessage(
        text: 'Fijate el login',
        imagePaths: const ['/tmp/a.png'],
        delivery: QueuedDelivery.interrupting,
      );

      final ida = QueuedMessage.fromJson(original.toJson());

      expect(ida, original);
      expect(ida.id, original.id);
      expect(ida.delivery, QueuedDelivery.interrupting);
    });

    test('una cola vieja sin fecha ni id no se pierde', () {
      // Perder un mensaje del usuario porque le falta una clave sería peor
      // que inventarle una.
      final message = QueuedMessage.fromJson({'text': 'hola'});

      expect(message.text, 'hola');
      expect(message.id, isNotEmpty);
      expect(message.delivery, QueuedDelivery.standby);
    });

    test('editar conserva la identidad y la fecha', () {
      final original = QueuedMessage(text: 'viejo');

      final editado = original.copyWith(text: 'nuevo');

      expect(editado.id, original.id);
      expect(editado.createdAt, original.createdAt);
      expect(editado.text, 'nuevo');
    });
  });
}
