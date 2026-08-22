import 'package:flutter/material.dart';

/// El disparador de la edición, para cuando el doble click no puede vivir
/// sobre el propio nombre.
///
/// En una fila del sidebar el gesto tiene que estar en el `InkWell` de la
/// fila entera, junto al tap que selecciona: dos detectores anidados pelean
/// en la arena y el tap simple queda esperando a que el doble se rinda —
/// medio segundo de demora para seleccionar algo.
class InlineRenameHandle extends ChangeNotifier {
  void start() => notifyListeners();
}

/// Un nombre que se edita donde está: doble click y el texto se convierte en
/// un campo, sin abrir nada.
///
/// El campo hereda [style] a propósito, así la fila no salta al entrar y
/// salir de edición — un salto de dos píxeles alcanza para que el gesto se
/// sienta roto.
///
/// Confirma al perder el foco y con Enter. Si [validate] rechaza el nombre,
/// **la edición no se cierra**: el error aparece debajo y el cursor sigue
/// donde estaba, que es donde hay que corregirlo.
class InlineRenameField extends StatefulWidget {
  const InlineRenameField({
    super.key,
    required this.value,
    required this.onRename,
    required this.style,
    required this.hintText,
    this.validate,
    this.openEmptyWhen,
    this.handle,
    this.tooltip = 'Doble click para renombrar',
  });

  final String value;

  /// Devuelve el error en castellano, o null si salió bien. Es la misma
  /// convención que los CRUD de los ViewModels, así que se enchufa directo.
  final String? Function(String name) onRename;

  /// Chequeo local, antes de molestar al ViewModel: formato del nombre.
  final String? Function(String name)? validate;

  final TextStyle style;
  final String hintText;

  /// Si el valor actual es este, el campo abre vacío. Sirve para los nombres
  /// por defecto ("Sesión nueva"): nadie quiere borrarlos a mano.
  final String? openEmptyWhen;

  /// Si viene, la edición la arranca quien lo tenga y este widget no pone
  /// ningún gesto propio.
  final InlineRenameHandle? handle;

  final String tooltip;

  @override
  State<InlineRenameField> createState() => _InlineRenameFieldState();
}

class _InlineRenameFieldState extends State<InlineRenameField> {
  bool _editing = false;
  String? _error;
  late final _controller = TextEditingController(text: widget.value);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.handle?.addListener(_startEditing);
  }

  @override
  void didUpdateWidget(InlineRenameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?.removeListener(_startEditing);
      widget.handle?.addListener(_startEditing);
    }
  }

  @override
  void dispose() {
    widget.handle?.removeListener(_startEditing);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.value == widget.openEmptyWhen ? '' : widget.value;
    setState(() {
      _editing = true;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  void _commit() {
    if (!_editing) return;
    final name = _controller.text.trim();

    // Salir sin cambiar nada no es un error: es cambiar de opinión.
    if (name == widget.value) {
      setState(() {
        _editing = false;
        _error = null;
      });
      return;
    }

    final error = widget.validate?.call(name) ?? widget.onRename(name);
    if (error != null) {
      setState(() => _error = error);
      _focusNode.requestFocus();
      return;
    }
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      final label = Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 900),
        child: Text(
          widget.value,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        ),
      );
      if (widget.handle != null) return label;
      return GestureDetector(
        onDoubleTap: _startEditing,
        behavior: HitTestBehavior.opaque,
        child: label,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _commit();
          },
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onSubmitted: (_) => _commit(),
            style: widget.style,
            cursorHeight: widget.style.fontSize,
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: widget.style.copyWith(color: scheme.outline),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 10.5, color: scheme.error),
            ),
          ),
      ],
    );
  }
}
