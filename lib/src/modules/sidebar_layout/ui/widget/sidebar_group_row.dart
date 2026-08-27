import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/inline_rename_field.dart';
import 'package:keel_ui/src/core/ui/sidebar_section_row.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';

/// La fila de un grupo hecho por el usuario.
///
/// Se dibuja con el mismo galón de 18×22 y el mismo contador que
/// [SidebarSectionRow], así un grupo se lee como hermano de Estado, Tableros
/// y Sesiones y no como un widget aparte que alguien pegó ahí.
///
/// El galón pliega; el doble click renombra. La fila NO navega —un grupo no
/// es un lugar al que ir— así que un click simple también pliega, que es lo
/// único que puede querer quien le apunta.
///
/// El botón derecho abre un menú. Antes deshacía el grupo en el acto, sin
/// preguntar y sin deshacer: la fila desaparecía y los miembros quedaban
/// sueltos, y el único aviso era un tooltip que solo se veía pasando el mouse
/// por encima del nombre. Un gesto que destruye algo tiene que pasar por una
/// elección visible.
class SidebarGroupRow extends StatefulWidget {
  const SidebarGroupRow({
    super.key,
    required this.group,
    required this.onToggle,
    required this.onRename,
    required this.onUngroup,
    this.containsSelection = false,
  });

  final SidebarGroupSlot group;
  final VoidCallback onToggle;
  final String? Function(String name) onRename;
  final VoidCallback onUngroup;

  /// Lo que está abierto vive adentro de este grupo.
  ///
  /// Se marca distinto de un ítem seleccionado a propósito: un ítem dice
  /// «esto es lo abierto» y se pinta con fondo lleno y barra izquierda; el
  /// grupo dice «lo abierto está acá adentro», que es otra cosa.
  final bool containsSelection;

  @override
  State<SidebarGroupRow> createState() => _SidebarGroupRowState();
}

class _SidebarGroupRowState extends State<SidebarGroupRow> {
  final _rename = InlineRenameHandle();

  @override
  void dispose() {
    _rename.dispose();
    super.dispose();
  }

  /// Renombrar y deshacer, que son las dos únicas cosas que se le pueden
  /// hacer a un grupo. Sale donde apuntaste, no en una esquina.
  Future<void> _openMenu(Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    final choice = await showMenu<_GroupAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _GroupAction.rename, child: Text('Renombrar')),
        PopupMenuItem(
          value: _GroupAction.ungroup,
          child: Text('Deshacer el grupo'),
        ),
      ],
    );
    if (!mounted) return;

    switch (choice) {
      case _GroupAction.rename:
        _rename.start();
      case _GroupAction.ungroup:
        widget.onUngroup();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = !widget.group.collapsed;

    return InkWell(
      onTap: widget.onToggle,
      onDoubleTap: _rename.start,
      onSecondaryTapDown: (details) => _openMenu(details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 3, 10, 3),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 22,
              child: Center(
                child: Icon(
                  open ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 16,
                  color: scheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: InlineRenameField(
                value: widget.group.name,
                handle: _rename,
                onRename: widget.onRename,
                hintText: 'Nombre del grupo',
                tooltip:
                    'Doble click para renombrar · '
                    'click derecho para más opciones',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: widget.containsSelection
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SidebarCount(
              widget.group.memberIds.length,
              highlight: widget.containsSelection,
            ),
          ],
        ),
      ),
    );
  }
}

enum _GroupAction { rename, ungroup }
