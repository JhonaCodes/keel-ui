import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';

/// Lo que contestó la última corrida.
///
/// Un paso solo se dibuja entero; con varios, cada uno en su fila y el
/// cuerpo del último —o del que falló, que es el que importa— desplegado.
class BoardResponsePane extends StatelessWidget {
  const BoardResponsePane({super.key, required this.run});

  final BoardRun run;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detailed = run.failure ?? run.steps.lastOrNull;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final step in run.steps) ...[
            _StepHeader(step: step, multiple: run.steps.length > 1),
            if (identical(step, detailed)) _Body(step: step),
          ],
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.multiple});

  final BoardStepResult step;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      color: scheme.outline,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(
            step.ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 14,
            color: step.ok ? scheme.tertiary : scheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            _statusLabel(step),
            style: mono.copyWith(
              fontWeight: FontWeight.w700,
              color: step.ok ? scheme.tertiary : scheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 10),
          Text('${step.elapsed.inMilliseconds} ms', style: mono),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: mono,
            ),
          ),
        ],
      ),
    );
  }

  /// Un HTTP habla en códigos; un comando, en salidas. Mostrar "0" al lado
  /// de un `echo` no significa nada para nadie.
  String _statusLabel(BoardStepResult step) => switch (step.kind) {
    BoardStepKind.http => step.status == 0 ? 'no salió' : '${step.status}',
    BoardStepKind.comando => step.ok ? 'ok' : 'salió ${step.status}',
  };
}

class _Body extends StatelessWidget {
  const _Body({required this.step});

  final BoardStepResult step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = step.ok ? step.output : step.error;
    if (text.trim().isEmpty && step.captured.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        if (text.trim().isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            child: SingleChildScrollView(
              child: SelectableText(
                _pretty(text),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.45,
                  color: step.ok
                      ? scheme.onSurfaceVariant
                      : scheme.onErrorContainer,
                ),
              ),
            ),
          ),
        if (step.captured.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
            child: Text(
              'guardó ${step.captured.keys.map((k) => '{{$k}}').join(', ')} '
              'para el paso siguiente',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
      ],
    );
  }

  /// Un JSON en una línea es ilegible, y las APIs contestan así. Lo que no
  /// sea JSON se muestra tal cual: forzarlo sería mentir sobre lo que llegó.
  String _pretty(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return trimmed;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
    } on FormatException {
      return trimmed;
    }
  }
}
