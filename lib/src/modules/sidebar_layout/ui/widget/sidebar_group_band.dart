import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/inline_rename_field.dart';
import 'package:keel_ui/src/core/ui/running_dot.dart';
import 'package:keel_ui/src/core/ui/sidebar_section_row.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';

/// Una banda de proyectos: una etiqueta global (trabajo, personal…) que
/// cruza la barra de lado a lado, con su color, y agrupa proyectos.
///
/// Se ve distinta a propósito de las filas de adentro de un proyecto
/// (Estado, Tableros, Sesiones): una banda no es una parte de nada, es un
/// corte de la lista. Un click la pliega, el doble click la renombra y el
/// botón derecho abre su menú. No navega: una banda no es un lugar.
class SidebarGroupBand extends StatefulWidget {
  const SidebarGroupBand({
    super.key,
    required this.group,
    required this.onToggle,
    required this.onRename,
    required this.onRemove,
    this.renameNow = false,
    this.containsSelection = false,
    this.runningCount = 0,
  });

  final SidebarGroupSlot group;
  final VoidCallback onToggle;
  final String? Function(String name) onRename;

  /// Quita la banda; sus proyectos quedan sueltos donde estaba.
  final VoidCallback onRemove;

  /// Recién creada: entra directo a escribir su nombre.
  final bool renameNow;

  /// Lo abierto está adentro de esta banda.
  final bool containsSelection;

  /// Cuántos proyectos de adentro están trabajando. Plegada, es lo único
  /// que lo dice.
  final int runningCount;

  @override
  State<SidebarGroupBand> createState() => _SidebarGroupBandState();
}

class _SidebarGroupBandState extends State<SidebarGroupBand> {
  final _rename = InlineRenameHandle();

  @override
  void initState() {
    super.initState();
    if (widget.renameNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rename.start();
      });
    }
  }

  @override
  void dispose() {
    _rename.dispose();
    super.dispose();
  }

  /// El color de la banda: sale del id, así no cambia al renombrarla ni al
  /// reordenar.
  Color get _color {
    var hash = 0;
    for (final unit in widget.group.id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return memberColorFor(hash % kProjectMemberPalette.length);
  }

  Future<void> _openMenu(Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final choice = await showMenu<_BandAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _BandAction.rename, child: Text('Renombrar')),
        PopupMenuItem(
          value: _BandAction.remove,
          child: Text('Quitar el grupo (los proyectos quedan sueltos)'),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case _BandAction.rename:
        _rename.start();
      case _BandAction.remove:
        widget.onRemove();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color;
    final open = !widget.group.collapsed;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Material(
        color: color.withValues(alpha: 0.13),
        child: InkWell(
          onTap: widget.onToggle,
          onDoubleTap: _rename.start,
          onSecondaryTapDown: (details) => _openMenu(details.globalPosition),
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
            child: Row(
              children: [
                Icon(
                  open ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InlineRenameField(
                    value: widget.group.name,
                    handle: _rename,
                    onRename: widget.onRename,
                    hintText: 'Nombre del grupo',
                    tooltip:
                        'Click: plegar · doble click: renombrar · '
                        'click derecho: más opciones',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: widget.containsSelection
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (widget.runningCount > 0) ...[
                  const SizedBox(width: 6),
                  RunningDot(count: widget.runningCount),
                ],
                const SizedBox(width: 6),
                SidebarCount(
                  widget.group.memberIds.length,
                  highlight: widget.containsSelection,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo que se ve adentro de una banda desplegada que todavía no tiene nada.
class SidebarGroupBandEmpty extends StatelessWidget {
  const SidebarGroupBandEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 14, 6),
      child: Text(
        'Vacío: arrastra un proyecto acá, o click derecho en un proyecto '
        '› Mover a este grupo.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

enum _BandAction { rename, remove }
