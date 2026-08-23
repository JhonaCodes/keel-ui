import 'package:flutter/material.dart';

/// Una sección de proyecto en el sidebar: Estado, Tableros, Sesiones.
///
/// Las tres se escriben con este widget y por eso se leen como hermanas. Ese
/// era el problema: Estado era una fila, Tableros un encabezado en
/// versalitas y las sesiones no tenían encabezado ninguno, así que la
/// jerarquía que el menú mostraba no era la que tenía.
///
/// La fila navega; el galón de la izquierda abre y cierra la lista. Son dos
/// gestos distintos a propósito: ir a los tableros y ver cuáles hay no son lo
/// mismo.
class SidebarSectionRow extends StatelessWidget {
  const SidebarSectionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.expanded,
    this.onToggle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Null en una sección sin lista debajo —Estado—, que igual reserva el
  /// lugar del galón para que las tres queden alineadas.
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = expanded ?? false;
    final glyphColor = selected ? scheme.primary : scheme.outlineVariant;

    // Rama y hoja se dibujan distinto a propósito: un triángulo que no
    // abre nada es una promesa que la fila no cumple. Estado no tiene lista
    // debajo, así que lleva un punto y no un galón —pero ocupa el mismo
    // lugar, que es lo que mantiene las tres alineadas.
    final glyph = SizedBox(
      width: 18,
      height: 22,
      child: onToggle == null
          ? Center(child: Icon(Icons.circle, size: 4, color: glyphColor))
          : InkWell(
              onTap: onToggle,
              child: Center(
                child: Icon(
                  open ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 16,
                  color: glyphColor,
                ),
              ),
            ),
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.fromLTRB(20, 3, 10, 3),
        child: Row(
          children: [
            glyph,
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? scheme.onSurface : scheme.outline,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ),
    );
  }
}

/// El contador que va al final de una sección. Monoespaciado y apagado: es
/// cuántos hay, no una alerta.
class SidebarCount extends StatelessWidget {
  const SidebarCount(this.value, {super.key, this.highlight = false});

  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      '$value',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: highlight ? scheme.primary : scheme.outline,
      ),
    );
  }
}

/// El «+ algo» que cuelga del final de una lista de sección.
class SidebarAddRow extends StatelessWidget {
  const SidebarAddRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(42, 4, 14, 6),
        child: Row(
          children: [
            Icon(Icons.add, size: 13, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
