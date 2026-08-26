import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/ui/widget/sidebar_drop_zone.dart';
import 'package:keel_ui/src/modules/sidebar_layout/ui/widget/sidebar_group_row.dart';
import 'package:keel_ui/src/modules/sidebar_layout/viewmodel/sidebar_layout_viewmodel.dart';

/// Una de las tres listas acomodables del sidebar, con sus grupos.
///
/// Existe para que proyectos, requerimientos y agentes sueltos se acomoden
/// EXACTAMENTE igual. Cada sección sigue dibujando su propia fila —un
/// proyecto no se ve como un agente— pero el arrastre, los grupos, el
/// pliegue y el orden son de acá, una sola vez.
class SidebarSectionList<T> extends StatelessWidget {
  const SidebarSectionList({
    super.key,
    required this.kind,
    required this.items,
    required this.idOf,
    required this.labelOf,
    required this.rowBuilder,
    this.belowBuilder,
  });

  final SidebarSectionKind kind;
  final List<T> items;
  final String Function(T item) idOf;

  /// El nombre que se ve pegado al cursor mientras se arrastra.
  final String Function(T item) labelOf;

  final Widget Function(T item) rowBuilder;

  /// Lo que cuelga de un ítem y NO se arrastra con él: las secciones del
  /// proyecto abierto. Va afuera de la zona de soltado, porque soltar sobre
  /// «Sesiones» no significa nada.
  final Widget Function(T item)? belowBuilder;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<SidebarLayoutViewModel, SidebarLayoutState>(
      viewmodel: SidebarLayoutService.instance.notifier,
      build: (state, layout, keep) {
        final byId = {for (final item in items) idOf(item): item};
        final present = byId.keys.toList();

        void dropped(String draggedId, String targetId, SidebarDropSpot spot) {
          layout.drop(
            kind,
            draggedId: draggedId,
            targetId: targetId,
            spot: spot,
            presentIds: present,
          );
        }

        Widget itemRow(String id, {required bool indented}) {
          final item = byId[id];
          if (item == null) return const SizedBox.shrink();
          final row = SidebarDropZone(
            id: id,
            kind: kind,
            label: labelOf(item),
            onDropped: (draggedId, spot) => dropped(draggedId, id, spot),
            child: indented
                ? Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: rowBuilder(item),
                  )
                : rowBuilder(item),
          );
          final below = belowBuilder?.call(item);
          if (below == null) return row;
          return Column(mainAxisSize: MainAxisSize.min, children: [row, below]);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final slot in layout.slotsFor(kind, present))
              switch (slot) {
                SidebarItemSlot(:final itemId) => itemRow(
                  itemId,
                  indented: false,
                ),
                SidebarGroupSlot() => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SidebarDropZone(
                      id: slot.id,
                      kind: kind,
                      label: slot.name,
                      onDropped: (draggedId, spot) =>
                          dropped(draggedId, slot.id, spot),
                      child: SidebarGroupRow(
                        group: slot,
                        onToggle: () => layout.toggleGroup(
                          kind,
                          slot.id,
                          presentIds: present,
                        ),
                        onRename: (name) => layout.renameGroup(
                          kind,
                          slot.id,
                          name,
                          presentIds: present,
                        ),
                        onUngroup: () =>
                            layout.ungroup(kind, slot.id, presentIds: present),
                      ),
                    ),
                    if (!slot.collapsed)
                      for (final memberId in slot.memberIds)
                        itemRow(memberId, indented: true),
                  ],
                ),
              },
          ],
        );
      },
    );
  }
}

/// El encabezado de una sección, que además saca cosas de un grupo.
///
/// Soltar acá arriba es la forma de deshacer una agrupación sin tener que
/// apuntarle a un hueco entre dos filas: el destino más grande y más obvio
/// de la sección es su propio título.
class SidebarSectionDropHead extends StatelessWidget {
  const SidebarSectionDropHead({
    super.key,
    required this.kind,
    required this.presentIds,
    required this.child,
  });

  final SidebarSectionKind kind;
  final List<String> presentIds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<SidebarDragData>(
      onWillAcceptWithDetails: (details) => details.data.kind == kind,
      onAcceptWithDetails: (details) {
        SidebarLayoutService.instance.notifier.moveToRoot(
          kind,
          details.data.id,
          presentIds: presentIds,
        );
      },
      builder: (context, candidate, rejected) => DecoratedBox(
        decoration: BoxDecoration(
          color: candidate.isEmpty
              ? null
              : scheme.primary.withValues(alpha: 0.12),
        ),
        child: child,
      ),
    );
  }
}
