import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/message_block.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/inline_file_editor.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';

final _epoch = DateTime(2026, 8, 28);

const _edit = FileEdit(
  path: '/repo/lib/orden.dart',
  beforeContent: 'antes',
  afterContent: 'despues',
);

/// El turno real que rompía: el modelo escribe, edita un archivo, y sigue
/// escribiendo. El colector se vacía en cada lectura, así que el tercer chunk
/// llega con la lista de ediciones VACÍA.
ChatMessage _turnoConEdicionEnElMedio() {
  var message = ChatMessage(
    role: ChatRole.assistant,
    text: '',
    timestamp: _epoch,
  );
  message = message.appendingChunk(text: 'Voy a tocar orden.dart.');
  message = message.appendingChunk(
    text: 'Listo, quedo asi.',
    fileEdits: const [_edit],
  );
  // El chunk que borraba la tarjeta: texto nuevo, cero ediciones.
  message = message.appendingChunk(text: ' Y ahora sigo explicando.');
  return message;
}

void main() {
  group('la secuencia de bloques de un turno en streaming', () {
    test('el texto que llega DESPUES de una edicion no la borra', () {
      final message = _turnoConEdicionEnElMedio();

      expect(
        message.fileEdits,
        const [_edit],
        reason:
            'la edicion capturada a mitad del turno tiene que seguir ahi '
            'despues del chunk de texto siguiente',
      );
    });

    test('el orden cronologico se conserva: texto, edicion, texto', () {
      final message = _turnoConEdicionEnElMedio();

      expect(message.blocks, const [
        MessageTextBlock('Voy a tocar orden.dart.'),
        MessageFileEditBlock(_edit),
        MessageTextBlock('Listo, quedo asi. Y ahora sigo explicando.'),
      ]);
    });

    test('el texto completo del mensaje no cambia', () {
      expect(
        _turnoConEdicionEnElMedio().text,
        'Voy a tocar orden.dart.Listo, quedo asi. Y ahora sigo explicando.',
      );
    });
  });

  group('la burbuja renderiza los bloques en orden', () {
    testWidgets('la tarjeta de edicion va ENTRE los dos textos', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          // The widgets under test read AppLocalizations; without the
          // delegates `AppLocalizations.of` returns null and build throws.
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: ChatMessageBubble(
                message: _turnoConEdicionEnElMedio(),
                agentId: 'agente-de-prueba',
                agentColor: Colors.deepPurple,
                fontScaleOverride: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textos = find.byType(MarkdownText);
      final tarjeta = find.byType(InlineFileEditor);

      expect(
        tarjeta,
        findsOneWidget,
        reason: 'la tarjeta de edicion tiene que estar visible en la burbuja',
      );
      expect(textos, findsNWidgets(2));

      final primerTexto = tester.getTopLeft(textos.at(0)).dy;
      final tarjetaY = tester.getTopLeft(tarjeta).dy;
      final segundoTexto = tester.getTopLeft(textos.at(1)).dy;

      expect(
        primerTexto,
        lessThan(tarjetaY),
        reason: 'el texto anterior a la edicion va arriba de la tarjeta',
      );
      expect(
        tarjetaY,
        lessThan(segundoTexto),
        reason:
            'el texto posterior a la edicion va DEBAJO de la tarjeta, no '
            'fusionado con el anterior ni con las tarjetas apiladas al final',
      );
    });
  });

  group('la persistencia del hilo', () {
    test('el round-trip conserva la secuencia', () {
      final message = _turnoConEdicionEnElMedio();
      final restored = ChatMessage.fromJson(
        jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
      );

      expect(restored.blocks, message.blocks);
      expect(restored, message);
    });

    test('un mensaje escrito antes de los bloques sigue cargando', () {
      final restored = ChatMessage.fromJson({
        'role': 'assistant',
        'text': 'Listo.',
        'timestamp': _epoch.toIso8601String(),
        'fileEdits': [_edit.toJson()],
      });

      expect(restored.text, 'Listo.');
      expect(restored.fileEdits, const [_edit]);
      expect(restored.blocks, const [
        MessageTextBlock('Listo.'),
        MessageFileEditBlock(_edit),
      ]);
    });
  });
}
