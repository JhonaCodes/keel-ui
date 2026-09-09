import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/running_dot.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/ui/widget/sidebar_section_list.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';

/// El grupo del sidebar, entre los proyectos y los agentes sueltos.
///
/// Muestra lo que sigue abierto, no todo: un requerimiento cerrado es
/// historia y vive en la pantalla de administración. La flecha es relativa
/// al proyecto seleccionado —`→` lo pide él, `←` se lo piden— porque es el
/// marco en el que estás parado cuando mirás esta columna.
class RequirementsGroup extends StatelessWidget {
  const RequirementsGroup({
    super.key,
    required this.selectedProjectId,
    required this.selectedRequirementId,
    required this.onSelect,
    required this.onManage,
    required this.onAdd,
  });

  final String? selectedProjectId;
  final String? selectedRequirementId;
  final ValueChanged<String> onSelect;
  final VoidCallback onManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ReactiveViewModelBuilder<RequirementsViewModel, RequirementsState>(
      viewmodel: RequirementsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final abiertos = state.requirements
            .where((requirement) => requirement.status.isOpen)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SidebarSectionDropHead(
              kind: SidebarSectionKind.requirement,
              presentIds: [for (final requirement in abiertos) requirement.id],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 22, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).sidebarSectionRequirements,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                    if (abiertos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${abiertos.length}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).sidebarTooltipAllRequirements,
                      icon: const Icon(Icons.tune, size: 15),
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onManage,
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).sidebarTooltipOpenRequirement,
                      icon: const Icon(Icons.add, size: 17),
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onAdd,
                    ),
                  ],
                ),
              ),
            ),
            if (abiertos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                child: Text(
                  AppLocalizations.of(context).sidebarRequirementsEmpty,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SidebarSectionList<InternalRequirement>(
              kind: SidebarSectionKind.requirement,
              items: abiertos,
              idOf: (requirement) => requirement.id,
              labelOf: (requirement) => requirement.code,
              selectedId: selectedRequirementId,
              runningIds: {
                for (final requirement in abiertos)
                  if (viewmodel.isThinking(requirement.id)) requirement.id,
              },
              rowBuilder: (requirement) => _RequirementRow(
                requirement: requirement,
                selectedProjectId: selectedProjectId,
                selected: selectedRequirementId == requirement.id,
                thinking: viewmodel.isThinking(requirement.id),
                onTap: () => onSelect(requirement.id),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.requirement,
    required this.selectedProjectId,
    required this.selected,
    required this.thinking,
    required this.onTap,
  });

  final InternalRequirement requirement;
  final String? selectedProjectId;
  final bool selected;

  /// Un agente está redactando su respuesta en este hilo.
  final bool thinking;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (glyph, color) = switch (selectedProjectId) {
      final id? when id == requirement.fromProjectId => (
        '→',
        const Color(0xFF4FA3D9),
      ),
      final id? when id == requirement.toProjectId => (
        '←',
        const Color(0xFFD98E5A),
      ),
      _ => ('·', scheme.outline),
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : null,
          border: Border(
            left: BorderSide(
              width: 2,
              color: selected ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        child: Row(
          children: [
            SizedBox(
              width: 11,
              child: Text(
                glyph,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              requirement.code.replaceAll('REQ-', ''),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: scheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                requirement.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (thinking) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: t.tooltipAgentAnsweringThread,
                child: const RunningDot(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
