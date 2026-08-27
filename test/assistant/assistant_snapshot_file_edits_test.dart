import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_state.dart';

final _epoch = DateTime.utc(2026, 8, 27);

void main() {
  FileEdit unaEdicion({int chars = 100}) => FileEdit(
    path: '/proyecto/app.dart',
    beforeContent: 'a' * chars,
    afterContent: 'b' * chars,
  );

  Agent conMensajes(List<ChatMessage> messages) => Agent(
    id: 'a',
    name: 'Keel AI',
    model: 'sonnet',
    createdAt: _epoch,
    iconColor: kAgentIconColorPalette.first,
    effort: 'medium',
    messages: messages,
  );

  ChatMessage conEdicion(int index, {int chars = 100}) => ChatMessage(
    role: ChatRole.assistant,
    text: 'toqué un archivo $index',
    timestamp: _epoch,
    fileEdits: [unaEdicion(chars: chars)],
  );

  group('las ediciones que cruzan a la ventana de Keel AI', () {
    test('las de los últimos mensajes viajan', () {
      // Antes se borraban todas y en la ventana veías que había tocado un
      // archivo sin poder abrirlo ni preguntar sobre una línea.
      final snapshot = AssistantAgentSnapshot.fromAgent(
        conMensajes([conEdicion(0)]),
      );

      expect(snapshot.messages.single.fileEdits, hasLength(1));
    });

    test('las viejas se caen: nadie abre un editor cien mensajes atrás', () {
      final snapshot = AssistantAgentSnapshot.fromAgent(
        conMensajes([for (var i = 0; i < 40; i++) conEdicion(i)]),
      );

      expect(snapshot.messages.first.fileEdits, isEmpty);
      expect(snapshot.messages.last.fileEdits, hasLength(1));
    });

    test('un diff gigante se cae solo él', () {
      // Es el único campo sin techo: el contenido entero del archivo antes y
      // después. Preferible perder UN botón que tumbar el empuje entero.
      final snapshot = AssistantAgentSnapshot.fromAgent(
        conMensajes([conEdicion(0, chars: 200 * 1024), conEdicion(1)]),
      );

      expect(snapshot.messages.first.fileEdits, isEmpty);
      expect(snapshot.messages.last.fileEdits, hasLength(1));
    });

    test('un mensaje sin ediciones pasa igual', () {
      final snapshot = AssistantAgentSnapshot.fromAgent(
        conMensajes([
          ChatMessage(role: ChatRole.user, text: 'hola', timestamp: _epoch),
        ]),
      );

      expect(snapshot.messages.single.text, 'hola');
      expect(snapshot.messages.single.fileEdits, isEmpty);
    });

    test('las ediciones sobreviven el JSON del cable', () {
      final snapshot = AssistantAgentSnapshot.fromAgent(
        conMensajes([conEdicion(0)]),
      );

      final ida = AssistantAgentSnapshot.fromJson(snapshot.toJson());

      expect(ida.messages.single.fileEdits.single.path, '/proyecto/app.dart');
    });
  });
}
