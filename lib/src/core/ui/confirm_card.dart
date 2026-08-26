import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Un detalle de la confirmación: lo que se lleva puesto, o lo que va a
/// pasar, con la parte que importa al frente.
typedef ConfirmDetail = ({String lead, String rest});

/// La única forma de preguntar «¿seguro?» en toda la app.
///
/// Antes había veintitrés diálogos y ninguno se parecía a la app: Material 3
/// de fábrica, esquinas de 28, ancho estirado hasta donde diera la ventana, y
/// nueve «¿Eliminar X?» copiados y pegados adentro de su propio tile. El
/// estilo que la app YA tenía era otro: la tarjeta con la que un agente pide
/// permiso ([PermissionRequestBanner]) — chica, con esquina suave y un borde
/// de acento que dice de qué se trata sin gritar.
///
/// Esto es esa tarjeta, flotando. Mismos colores, mismo radio, mismo par de
/// botones a la derecha.
///
/// [details] enumera lo que se va ANTES de que se vaya, no después.
/// [reassurance] existe porque la pregunta que todo el mundo tiene en la
/// cabeza —«¿me borra la carpeta?»— merece estar contestada acá y no en el
/// susto de después.
///
/// [typeToConfirm] pide escribir un nombre exacto para habilitar el botón. No
/// es una traba: es el segundo de pausa que hace falta para leer qué se
/// lleva. Va solo donde no hay vuelta atrás —un proyecto con sus sesiones,
/// sus hilos y el contexto que los agentes acumularon—; una regla se vuelve a
/// escribir y no lo necesita.
Future<bool> confirmWithCard(
  BuildContext context, {
  required String title,
  String? body,
  List<ConfirmDetail> details = const [],
  String? reassurance,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool monospaceDetails = false,
  String? typeToConfirm,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, animation, secondaryAnimation) => _ConfirmCard(
      title: title,
      body: body,
      details: details,
      reassurance: reassurance,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      monospaceDetails: monospaceDetails,
      typeToConfirm: typeToConfirm,
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        // Apenas: una tarjeta que entra creciendo del todo se lee como un
        // sobresalto, y esto ya interrumpe bastante.
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return confirmed ?? false;
}

class _ConfirmCard extends StatefulWidget {
  const _ConfirmCard({
    required this.title,
    required this.body,
    required this.details,
    required this.reassurance,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.monospaceDetails,
    required this.typeToConfirm,
  });

  final String title;
  final String? body;
  final List<ConfirmDetail> details;
  final String? reassurance;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;

  /// Para detalles que son literales —comandos, rutas—: lo que hay que leer
  /// carácter por carácter no se lee en la tipografía del cuerpo.
  final bool monospaceDetails;

  final String? typeToConfirm;

  @override
  State<_ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends State<_ConfirmCard> {
  final _controller = TextEditingController();

  bool get _asksToType => widget.typeToConfirm != null;
  bool get _canConfirm =>
      !_asksToType || _controller.text.trim() == widget.typeToConfirm;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(bool confirmed) => Navigator.of(context).pop(confirmed);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context);
    // El acento dice de qué se trata antes de leer una palabra: rojo cuando
    // algo se va, latón cuando solo hay que decidir.
    final accent = widget.destructive ? scheme.error : scheme.primary;
    final wide = widget.details.isNotEmpty || _asksToType;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 520 : 460),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              color: scheme.surfaceContainerHigh,
              shape: 16.smoothBorder(
                side: BorderSide(color: accent.withValues(alpha: 0.3)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      widget.destructive
                          ? Icons.delete_outline
                          : Icons.help_outline,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.body case final body? when body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      body,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                if (widget.details.isNotEmpty ||
                    widget.reassurance != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            width: 2,
                            color: scheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in widget.details)
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
                                style: text.bodySmall?.copyWith(
                                  fontSize: 12,
                                  fontFamily: widget.monospaceDetails
                                      ? 'monospace'
                                      : null,
                                ),
                              ),
                            ),
                          if (widget.reassurance case final calma?)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                calma,
                                style: text.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: scheme.tertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (widget.typeToConfirm case final expected?) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Escribí '),
                              TextSpan(
                                text: expected,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' para confirmar'),
                            ],
                          ),
                          style: text.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _controller,
                          autofocus: true,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (_canConfirm) _close(true);
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _close(false),
                      child: Text(widget.cancelLabel ?? t.buttonCancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _canConfirm ? () => _close(true) : null,
                      style: widget.destructive
                          ? FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                            )
                          : null,
                      child: Text(widget.confirmLabel ?? t.buttonDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
