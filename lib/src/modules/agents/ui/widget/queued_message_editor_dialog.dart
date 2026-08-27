import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agents/model/queued_message.dart';

/// Reescribir un mensaje que todavía no salió.
///
/// Devuelve el texto ya con las referencias restauradas: en pantalla se
/// edita el texto LEGIBLE (`@agente`, `/carpeta`), pero lo que se guarda
/// lleva los enlaces `keel://` de vuelta — si no, editar una coma convertiría
/// cada referencia en texto muerto.
class QueuedMessageEditorDialog extends StatefulWidget {
  const QueuedMessageEditorDialog({super.key, required this.message});

  final QueuedMessage message;

  @override
  State<QueuedMessageEditorDialog> createState() =>
      _QueuedMessageEditorDialogState();
}

class _QueuedMessageEditorDialogState extends State<QueuedMessageEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ChatReferenceService.visibleText(widget.message.text),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty && widget.message.imagePaths.isEmpty) return;
    Navigator.of(context).pop(
      ChatReferenceService.restoreReferencesAfterEdit(
        widget.message.text,
        text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar mensaje en espera'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Mensaje que se enviará en el próximo turno',
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
