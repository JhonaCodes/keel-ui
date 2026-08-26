import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/viewmodel/sidebar_layout_viewmodel.dart';

/// Lo que se arrastra: el id de un ítem o de un grupo, y de qué sección es.
///
/// La sección viaja adentro para que soltar un proyecto sobre un agente no
/// haga nada. Sin eso, las tres listas del sidebar serían un solo tablero y
/// se podrían mezclar cosas que no se pueden mezclar.
typedef SidebarDragData = ({String id, SidebarSectionKind kind});

/// Una fila que se puede arrastrar y sobre la que se puede soltar.
///
/// La fila se divide en tres bandas y ahí está toda la idea: por el cuarto de
/// arriba y el de abajo se ORDENA —aparece una línea— y por la mitad del
/// medio se AGRUPA —se ilumina la fila entera—. Un solo gesto, dos
/// significados, y cuál va a pasar se ve antes de soltar.
class SidebarDropZone extends StatefulWidget {
  const SidebarDropZone({
    super.key,
    required this.id,
    required this.kind,
    required this.label,
    required this.child,
    required this.onDropped,
    this.acceptsInto = true,
    this.draggable = true,
  });

  final String id;
  final SidebarSectionKind kind;

  /// Lo que se ve mientras se arrastra. El nombre alcanza: la fila entera
  /// pegada al cursor tapa la lista justo cuando hay que mirarla.
  final String label;

  final Widget child;
  final void Function(String draggedId, SidebarDropSpot spot) onDropped;

  /// Un grupo no recibe otro grupo adentro; ahí las tres bandas se reducen a
  /// dos.
  final bool acceptsInto;

  final bool draggable;

  @override
  State<SidebarDropZone> createState() => _SidebarDropZoneState();
}

class _SidebarDropZoneState extends State<SidebarDropZone> {
  SidebarDropSpot? _hovering;

  SidebarDropSpot _spotFor(Offset localPosition, double height) {
    if (!widget.acceptsInto) {
      return localPosition.dy < height / 2
          ? SidebarDropSpot.before
          : SidebarDropSpot.after;
    }
    if (localPosition.dy < height * 0.25) return SidebarDropSpot.before;
    if (localPosition.dy > height * 0.75) return SidebarDropSpot.after;
    return SidebarDropSpot.into;
  }

  bool _accepts(SidebarDragData? data) =>
      data != null && data.kind == widget.kind && data.id != widget.id;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final target = DragTarget<SidebarDragData>(
      onWillAcceptWithDetails: (details) => _accepts(details.data),
      onMove: (details) {
        if (!_accepts(details.data)) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        // `details.offset` es el puntero y no la esquina del arrastre
        // porque el Draggable usa `pointerDragAnchorStrategy`: la banda se
        // calcula justo donde el usuario está apuntando.
        final local = box.globalToLocal(details.offset);
        final spot = _spotFor(local, box.size.height);
        if (spot != _hovering) setState(() => _hovering = spot);
      },
      onLeave: (_) => setState(() => _hovering = null),
      onAcceptWithDetails: (details) {
        final spot = _hovering ?? SidebarDropSpot.after;
        setState(() => _hovering = null);
        widget.onDropped(details.data.id, spot);
      },
      builder: (context, candidate, rejected) {
        final spot = _hovering;
        return Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: spot == SidebarDropSpot.into
                    ? scheme.primary.withValues(alpha: 0.16)
                    : null,
              ),
              child: widget.child,
            ),
            if (spot == SidebarDropSpot.before)
              Positioned(left: 8, right: 8, top: 0, child: _Line()),
            if (spot == SidebarDropSpot.after)
              Positioned(left: 8, right: 8, bottom: 0, child: _Line()),
          ],
        );
      },
    );

    if (!widget.draggable) return target;

    return Draggable<SidebarDragData>(
      data: (id: widget.id, kind: widget.kind),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragLabel(label: widget.label),
      childWhenDragging: Opacity(opacity: 0.35, child: target),
      child: target,
    );
  }
}

class _Line extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _DragLabel extends StatelessWidget {
  const _DragLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Transform.translate(
        offset: const Offset(10, -10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
