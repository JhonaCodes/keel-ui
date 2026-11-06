import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/integrations/laya/laya.dart';
import 'package:keel_ui/src/modules/laya/model/laya_labels.dart';
import 'package:keel_ui/src/modules/laya/model/laya_state.dart';
import 'package:keel_ui/src/modules/laya/viewmodel/laya_viewmodel.dart';

/// Laya mirando las tareas abiertas del proyecto: cuáles están demoradas y
/// qué conviene hacer con cada una, con sus probabilidades. Solo
/// recomienda: no cambia ninguna tarea.
///
/// No aparece si la bóveda no tiene Laya.
class LayaTaskReview extends StatelessWidget {
  const LayaTaskReview({super.key, required this.projectPath});

  final String projectPath;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<LayaViewModel, LayaState>(
      viewmodel: LayaService.instance.notifier,
      build: (state, viewmodel, keep) {
        if (!state.configured) return const SizedBox.shrink();
        final review = state.reviewOf(projectPath);
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      review.at == null
                          ? 'Laya: ¿qué tareas están demoradas?'
                          : 'Laya: ${review.delayed.length} demoradas · '
                                '${review.onTrack} al día',
                      style: text.labelLarge,
                    ),
                  ),
                  if (review.loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => viewmodel.reviewTasks(projectPath),
                      icon: const Icon(Icons.refresh, size: 15),
                      label: Text(
                        review.at == null
                            ? 'Revisar tareas con Laya'
                            : 'Revisar de nuevo',
                      ),
                    ),
                ],
              ),
              if (review.error.isNotEmpty)
                Text(
                  review.error,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              if (review.at != null &&
                  review.error.isEmpty &&
                  review.delayed.isEmpty)
                Text(
                  'Ninguna tarea abierta parece demorada.',
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              for (final verdict in review.delayed)
                LayaTaskVerdictRow(verdict: verdict),
              if (review.at != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Laya solo recomienda: no cambia ninguna tarea.',
                    style: text.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Una tarea demorada: por qué lo parece y las opciones, la recomendada
/// primero.
class LayaTaskVerdictRow extends StatelessWidget {
  const LayaTaskVerdictRow({super.key, required this.verdict});

  final LayaTaskVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  verdict.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ),
              Text(
                'demorada ${LayaLabels.percent(verdict.delayed)}',
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ),
          Text(
            '${verdict.state} · ${LayaLabels.idle(verdict.daysIdle)} · '
            '${verdict.taskPath}',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final MapEntry(key: option, value: probability)
                  in verdict.options.entries)
                Chip(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: option == verdict.action
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                  label: Text(
                    '${LayaLabels.action(option)} '
                    '${LayaLabels.percent(probability)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: option == verdict.action
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            'Recomienda ${LayaLabels.action(verdict.action)} — '
            '${LayaLabels.confidence(verdict.actionConfidence)}.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
