import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Elegir con qué workflow adaptativo corre algo. Devuelve el id, o null si
/// te fuiste.
///
/// Existe porque un proyecto hace trabajos de clases distintas —armar la
/// carpeta de tareas, resolver un ticket, evaluar un requerimiento— y cada
/// uno quiere otra fila de agentes. Acá es donde `whenToApply` por fin sirve
/// para algo: se escribía, se guardaba y no lo leía nadie para decidir.
Future<String?> openWorkflowPicker(
  BuildContext context, {
  required List<Workflow> options,
  required String currentId,
  required String title,
  required String note,
}) {
  return showFormPanel<String>(
    context,
    width: 520,
    child: _WorkflowPicker(
      options: options,
      currentId: currentId,
      title: title,
      note: note,
    ),
  );
}

class _WorkflowPicker extends StatelessWidget {
  const _WorkflowPicker({
    required this.options,
    required this.currentId,
    required this.title,
    required this.note,
  });

  final List<Workflow> options;
  final String currentId;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            note,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          for (final workflow in options)
            _Option(
              workflow: workflow,
              current: workflow.id == currentId,
              onPick: () => Navigator.of(context).pop(workflow.id),
            ),
          if (options.isEmpty)
            Text(
              'Este proyecto no tiene ningún workflow enganchado. Agregale '
              'uno desde el formulario del proyecto.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.workflow,
    required this.current,
    required this.onPick,
  });

  final Workflow workflow;
  final bool current;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: current ? scheme.primary : scheme.outlineVariant,
                width: current ? 1 : 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workflow.name,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          color: current ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      // Para qué sirve, escrito por quien lo armó.
                      if (workflow.whenToApply.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          workflow.whenToApply.trim(),
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        [
                          workflow.kind.name,
                          workflow.policy.resolutionRole.isEmpty
                              ? 'responsable dinámico'
                              : workflow.policy.resolutionRole,
                          '${workflow.policy.maxReplans} reformulaciones',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (current) Icon(Icons.check, size: 16, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
