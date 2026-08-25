import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// El campo de escritura de cualquier chat. Acepta MULTILÍNEA, que es la
/// diferencia entera con un `TextField` suelto.
///
/// Un campo de una sola línea (`maxLines: 1`, el default) descarta los
/// saltos al pegar: una tabla markdown llega convertida en un renglón, y
/// las palabras de dos líneas distintas quedan pegadas ("sin\nresumir" →
/// "sinresumir"). Después no hay markdown que valga, porque el texto ya
/// perdió su estructura antes de salir del composer.
///
/// **Enter envía. Shift+Enter salta de línea.** Es lo que espera cualquiera
/// que escriba en un chat, y la única forma de escribir un prompt largo sin
/// pegarlo de otro lado.
class ChatComposerField extends StatefulWidget {
  const ChatComposerField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.hintText,
    this.enabled = true,
    this.onChanged,
    this.onKeyEvent,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Gets first refusal on keyboard events. Autocomplete uses it for arrows,
  /// Escape and Enter; returning [KeyEventResult.ignored] preserves the normal
  /// composer behavior.
  final KeyEventResult Function(KeyEvent event)? onKeyEvent;

  @override
  State<ChatComposerField> createState() => _ChatComposerFieldState();
}

class _ChatComposerFieldState extends State<ChatComposerField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final externalResult = widget.onKeyEvent?.call(event);
    if (externalResult == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    // Con shift el salto de línea es del campo, no nuestro.
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;

    widget.onSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _onKey,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        minLines: 1,
        // Crece hasta seis renglones y de ahí scrollea: un prompt largo se
        // puede releer antes de mandarlo, sin comerse el hilo.
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
