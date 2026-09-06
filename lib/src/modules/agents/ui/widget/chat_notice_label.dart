import 'package:flutter/material.dart';
import 'package:info_label/info_label.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';

/// Una nota del hilo que no escribió nadie: una falla de ejecución, o un
/// cierre bloqueado del workflow.
///
/// Existe como widget —y no como dos ramas repetidas en cada burbuja— para
/// que el rojo con ícono de excepción quede RESERVADO para la falla. Cuando
/// el hilo pintaba las dos cosas igual, un caso bloqueado, que es un
/// resultado esperado del workflow, se leía como un crash de la app. Acá
/// está el único lugar donde se decide cuál es cuál.
class ChatNoticeLabel extends StatelessWidget {
  const ChatNoticeLabel({
    super.key,
    required this.role,
    required this.text,
    required this.fontSize,
  });

  final ChatRole role;
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Sin `default`: un rol nuevo rompe la compilación acá, en vez de
    // heredar en silencio el estilo de la falla.
    final (type, icon) = switch (role) {
      ChatRole.error => (TypeInfoLabel.error, Icons.error_outline),
      ChatRole.blocked => (TypeInfoLabel.warning, Icons.block),
      // Un mensaje de una persona, de un agente o una nota de la app no
      // llega acá: las burbujas lo atajan antes. Si alguna vez llegara, se
      // ve como información neutra — nunca como una falla.
      ChatRole.user ||
      ChatRole.assistant ||
      ChatRole.system => (TypeInfoLabel.neutral, Icons.info_outline),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InfoLabel(
          text: text,
          typeInfoLabel: type,
          leftIcon: Icon(icon, size: 14),
          fontSize: fontSize,
        ),
      ),
    );
  }
}
