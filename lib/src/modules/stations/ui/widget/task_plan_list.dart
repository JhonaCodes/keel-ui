import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/stations/model/task_plan_item.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';

/// El plan de trabajo de una tarea, colgando de ella en el sidebar.
///
/// Los pasos del workflow (`3/7`) dicen QUIÉN sigue; esto dice QUÉ falta de
/// lo que se acordó. Son dos cosas distintas y por eso se ven las dos: un
/// plan cumplido a medias con el workflow en el paso 5 es información que no
/// se deduce de ninguna de las dos por separado.
class TaskPlanList extends StatelessWidget {
  const TaskPlanList({
    super.key,
    required this.stationId,
    required this.taskId,
    required this.plan,
    required this.taskIsRunning,
  });

  final String stationId;
  final String taskId;
  final List<TaskPlanItem> plan;

  /// Con la tarea corriendo no se ofrece arrancar otro ciclo: ya hay uno.
  final bool taskIsRunning;

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
              onToggle: () => StationsService.instance.notifier.togglePlanItem(
                stationId,
                taskId,
                item.id,
              ),
              onRemove: () => StationsService.instance.notifier.removePlanItem(
                stationId,
                taskId,
                item.id,
              ),
            ),
          if (plan.isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 18),
              child: Text(
                'plan completo',
                style: TextStyle(fontSize: 10, color: scheme.tertiary),
              ),
            )
          // Cada punto pendiente es otra vuelta entera del workflow, desde el
          // paso 1. Estaba solo como palabra escrita en el chat ("continuar"),
          // que es pedirle al usuario que adivine el conjuro.
          else if (!taskIsRunning && current != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 16, bottom: 2),
              child: TextButton.icon(
                onPressed: () => StationsService.instance.notifier
                    .continueWithNextPlanItem(stationId, taskId),
                icon: const Icon(Icons.play_circle_outline, size: 14),
                label: Text(
                  'Seguir con "${current.text}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 10.5, height: 1.2),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
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

  final TaskPlanItem item;
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

    final (icon, color) = switch ((item.done, widget.isCurrent)) {
      (true, _) => (Icons.check, scheme.tertiary),
      (false, true) => (Icons.play_arrow, scheme.primary),
      (false, false) => (Icons.circle_outlined, scheme.outlineVariant),
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
                        color: item.done ? scheme.outline : scheme.onSurface,
                        decoration: item.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: scheme.outline,
                        fontWeight: widget.isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    // A qué PUESTO le toca — no a qué agente: el mismo plan
                    // sirve en la estación de Rust y en la de Flutter, donde
                    // ese puesto lo ocupa otro.
                    if (item.ownerRole != null && !item.done)
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
