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
class SidebarGroupRow extends StatefulWidget {
  const SidebarGroupRow({
    super.key,
    required this.group,
    required this.onToggle,
    required this.onRename,
    required this.onUngroup,
  });

  final SidebarGroupSlot group;
  final VoidCallback onToggle;
  final String? Function(String name) onRename;
  final VoidCallback onUngroup;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = !widget.group.collapsed;

    return InkWell(
      onTap: widget.onToggle,
      onDoubleTap: _rename.start,
      onSecondaryTap: widget.onUngroup,
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
                    'click derecho para deshacer el grupo',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SidebarCount(widget.group.memberIds.length),
          ],
        ),
      ),
    );
  }
}
