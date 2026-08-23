import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

/// El plan de trabajo de una sesión, colgando de ella en el sidebar.
///
/// Los pasos del workflow (`3/7`) dicen QUIÉN sigue; esto dice QUÉ falta de
/// lo que se acordó. Son dos cosas distintas y por eso se ven las dos: un
/// plan cumplido a medias con el workflow en el paso 5 es información que no
/// se deduce de ninguna de las dos por separado.
class SessionPlanList extends StatelessWidget {
  const SessionPlanList({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.plan,
  });

  final String projectId;
  final String sessionId;
  final List<SessionPlanItem> plan;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final current = plan.current;

    return Padding(
      padding: const EdgeInsets.only(left: 44, right: 8, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in plan)
            _PlanRow(
              item: item,
              isCurrent: item.id == current?.id,
              onToggle: () => ProjectsService.instance.notifier.togglePlanItem(
                projectId,
                sessionId,
                item.id,
              ),
              onRemove: () => ProjectsService.instance.notifier.removePlanItem(
                projectId,
                sessionId,
                item.id,
              ),
            ),
          if (plan.isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 18),
              child: Text(
                plan.discardedCount == 0
                    ? 'plan completo'
                    : 'plan cerrado · ${plan.discardedCount} descartados',
                style: TextStyle(
                  fontSize: 10,
                  color: plan.discardedCount == 0
                      ? scheme.tertiary
                      : scheme.outline,
                ),
              ),
            ),
          // Acá había un botón para arrancar el próximo punto. Se movió a la
          // barra que va arriba del campo de escribir: esta columna es
          // contexto, y una acción escondida al fondo del contexto no la
          // encuentra nadie. Lo que queda es la lista, que es lo que hay
          // que mirar.
        ],
      ),
    );
  }
}

/// Un punto: estado, texto y —al pasar el mouse— la cruz para sacarlo.
class _PlanRow extends StatefulWidget {
  const _PlanRow({
    required this.item,
    required this.isCurrent,
    required this.onToggle,
    required this.onRemove,
  });

  final SessionPlanItem item;
  final bool isCurrent;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  State<_PlanRow> createState() => _PlanRowState();
}

class _PlanRowState extends State<_PlanRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;

    // Tres estados, no dos: descartado NO es cumplido. El tachado los une
    // —los dos salieron de la lista de lo que falta— y el icono los separa.
    final (icon, color) = switch ((item.discarded, item.done)) {
      (true, _) => (Icons.do_not_disturb_alt, scheme.outlineVariant),
      (_, true) => (Icons.check, scheme.tertiary),
      _ when widget.isCurrent => (Icons.play_arrow, scheme.primary),
      _ => (Icons.circle_outlined, scheme.outlineVariant),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: item.pending ? scheme.onSurface : scheme.outline,
                        decoration: item.pending
                            ? null
                            : TextDecoration.lineThrough,
                        decorationColor: scheme.outline,
                        fontWeight: widget.isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    // A qué PUESTO le toca — no a qué agente: el mismo plan
                    // sirve en el proyecto de Rust y en la de Flutter, donde
                    // ese puesto lo ocupa otro.
                    if (item.ownerRole != null && item.pending)
                      Text(
                        item.ownerRole!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: scheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              // La cruz aparece solo bajo el mouse: con doce puntos en la
              // lista, doce cruces permanentes son ruido.
              if (_hovering)
                InkWell(
                  onTap: widget.onRemove,
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: scheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
