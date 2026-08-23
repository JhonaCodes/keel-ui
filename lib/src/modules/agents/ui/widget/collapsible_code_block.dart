import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Un bloque ```código``` de un mensaje: una tarjeta compacta de máximo dos
/// filas, nunca el código expandido en el hilo.
///
/// El [CodeField] de gpt_markdown no tiene techo de alto: un `git diff` o el
/// resultado completo de un `Read` pegado en la respuesta de un agente se
/// renderiza entero, y el scroll de la ventana de chat queda atrapado
/// adentro de esa caja. Acá el código nunca se dibuja en el hilo: la tarjeta
/// muestra el lenguaje y la cantidad de líneas, con dos acciones — "Ver"
/// abre el código completo en el panel lateral que ya usa el resto de la
/// app ([showFormPanel], el equivalente de un end drawer), y "Cerrar" saca
/// la tarjeta del mensaje.
class CollapsibleCodeBlock extends StatefulWidget {
  const CollapsibleCodeBlock({
    super.key,
    required this.name,
    required this.code,
  });

  /// El lenguaje escrito después del fence de apertura.
  final String name;

  /// El código en sí.
  final String code;

  @override
  State<CollapsibleCodeBlock> createState() => _CollapsibleCodeBlockState();
}

class _CollapsibleCodeBlockState extends State<CollapsibleCodeBlock> {
  bool _closed = false;

  int get _lineCount => widget.code.split('\n').length;

  String get _language => widget.name.trim().isEmpty ? 'texto' : widget.name;

  Future<void> _ver() => showFormPanel<void>(
    context,
    width: 720,
    child: _CodeBlockPanel(name: widget.name, code: widget.code),
  );

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: 10.smoothBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_language · $_lineCount líneas',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _ver,
                icon: const Icon(Icons.visibility_outlined, size: 14),
                label: const Text('Ver'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _closed = true),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Cerrar'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El código completo, dentro del panel lateral que abre "Ver".
class _CodeBlockPanel extends StatelessWidget {
  const _CodeBlockPanel({required this.name, required this.code});

  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name.trim().isEmpty ? 'Código' : name)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: CodeField(name: name, codes: code),
        ),
      ),
    );
  }
}
