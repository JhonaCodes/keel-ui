import 'package:flutter/material.dart';

/// Una consecuencia del borrado: lo que se lleva, con la cantidad al frente.
typedef DeletionConsequence = ({String lead, String rest});

/// Confirmación de un borrado que hay que escribir para que pase.
///
/// El resto de los borrados de la app se confirman con un botón, y está bien:
/// una regla se vuelve a escribir. Un proyecto no — se lleva sus sesiones,
/// sus hilos y el contexto que los agentes acumularon. Escribir el nombre no
/// es una traba: es el segundo de pausa que hace falta para leer qué se va.
///
/// [consequences] se enumera ANTES de que pase, no después. Y [reassurance]
/// existe porque la pregunta que todo el mundo tiene en la cabeza —«¿me borra
/// la carpeta?»— merece estar contestada en el mismo diálogo.
Future<bool> confirmTypedDeletion(
  BuildContext context, {
  required String title,
  required String expected,
  required List<DeletionConsequence> consequences,
  String? reassurance,
  String confirmLabel = 'Eliminar',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _TypedDeletionDialog(
      title: title,
      expected: expected,
      consequences: consequences,
      reassurance: reassurance,
      confirmLabel: confirmLabel,
    ),
  );
  return confirmed ?? false;
}

class _TypedDeletionDialog extends StatefulWidget {
  const _TypedDeletionDialog({
    required this.title,
    required this.expected,
    required this.consequences,
    required this.reassurance,
    required this.confirmLabel,
  });

  final String title;
  final String expected;
  final List<DeletionConsequence> consequences;
  final String? reassurance;
  final String confirmLabel;

  @override
  State<_TypedDeletionDialog> createState() => _TypedDeletionDialogState();
}

class _TypedDeletionDialogState extends State<_TypedDeletionDialog> {
  final _controller = TextEditingController();

  bool get _matches => _controller.text.trim() == widget.expected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Esto no se puede deshacer.', style: text.bodyMedium),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(width: 2, color: scheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in widget.consequences)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: item.lead,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.rest.isNotEmpty)
                              TextSpan(
                                text: ' ${item.rest}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        style: text.bodyMedium,
                      ),
                    ),
                  if (widget.reassurance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.reassurance!,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Escribí '),
                  TextSpan(
                    text: widget.expected,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' para confirmar'),
                ],
              ),
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_matches) Navigator.of(context).pop(true);
              },
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
