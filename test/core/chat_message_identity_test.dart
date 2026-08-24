import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';

final _epoch = DateTime(2026, 8, 23);

ChatMessage _base() => ChatMessage(
  role: ChatRole.assistant,
  text: 'Listo.',
  timestamp: _epoch,
  costUsd: 0.1,
  durationMs: 1000,
  reasoning: 'Pensé un rato.',
  fileEdits: const [
    FileEdit(path: 'a.dart', beforeContent: 'uno', afterContent: 'dos'),
  ],
  imagePaths: const ['/img/uno.png'],
  authorProfileId: 'flutter-expert',
  workNodeId: 'implementation',
  consultOfProfileId: null,
);

void main() {
  // El repositorio saltea escribir un mensaje cuyo hash no cambió, para no
  // re-serializar el contenido entero de cada archivo editado en cada turno.
  // Un campo que quede afuera del hash es un cambio que NUNCA se guarda, y
  // el síntoma aparece recién al reabrir la app.
  group('el hash de un mensaje cambia con cada campo', () {
    final variantes = <String, ChatMessage>{
      'role': ChatMessage(
        role: ChatRole.user,
        text: _base().text,
        timestamp: _epoch,
      ),
      'text': ChatMessage(
        role: ChatRole.assistant,
        text: 'Otra cosa.',
        timestamp: _epoch,
      ),
      'timestamp': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: DateTime(2026, 8, 24),
      ),
      'costUsd': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        costUsd: 0.2,
      ),
      'durationMs': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        durationMs: 2000,
      ),
      'reasoning': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        reasoning: 'Otro razonamiento.',
      ),
      'fileEdits': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        fileEdits: const [
          FileEdit(path: 'b.dart', beforeContent: null, afterContent: 'x'),
        ],
      ),
      'imagePaths': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        imagePaths: const ['/img/dos.png'],
      ),
      'authorProfileId': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        authorProfileId: 'rn-expert',
      ),
      'workNodeId': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        workNodeId: 'verification',
      ),
      'consultOfProfileId': ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        consultOfProfileId: 'arquitecto',
      ),
    };

    final desnudo = ChatMessage(
      role: ChatRole.assistant,
      text: 'Listo.',
      timestamp: _epoch,
    );

    for (final entry in variantes.entries) {
      test('${entry.key} entra en el hash', () {
        expect(
          entry.value.hashCode,
          isNot(desnudo.hashCode),
          reason:
              'Cambiar ${entry.key} no movió el hash: el repositorio '
              'saltearía esa escritura y el cambio no se guardaría nunca.',
        );
      });
    }

    test('cambiar el CONTENIDO de un archivo editado mueve el hash', () {
      final otro = ChatMessage(
        role: ChatRole.assistant,
        text: 'Listo.',
        timestamp: _epoch,
        fileEdits: const [
          FileEdit(path: 'a.dart', beforeContent: 'uno', afterContent: 'TRES'),
        ],
      );
      expect(otro.hashCode, isNot(_base().hashCode));
    });

    test('dos mensajes iguales tienen el mismo hash', () {
      expect(_base().hashCode, _base().hashCode);
      expect(_base(), _base());
    });
  });
}
