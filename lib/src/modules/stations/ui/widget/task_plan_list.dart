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
  });

  final String stationId;
  final String taskId;
  final List<TaskPlanItem> plan;

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
                child: Text(
                  item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: item.done ? scheme.outline : scheme.onSurface,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    decorationColor: scheme.outline,
                    fontWeight: widget.isCurrent
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
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
