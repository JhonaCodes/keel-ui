import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/modules/boards/ui/screen/board_form_screen.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';

/// Los tableros de un proyecto, en el sidebar, entre Estado y las sesiones.
///
/// Van acá y no en una sección aparte porque un tablero prueba la API de
/// ESTE repo: sacarlo del proyecto sería pedirte que te acuerdes a cuál
/// pertenece. Y van después de Estado porque son herramienta, no resumen.
class BoardsGroup extends StatelessWidget {
  const BoardsGroup({
    super.key,
    required this.projectId,
    required this.selectedBoardId,
    required this.onSelect,
  });

  final String projectId;
  final String? selectedBoardId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<BoardsViewModel, BoardsState>(
      viewmodel: BoardsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final boards = state.forProject(projectId);
        final scheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => openBoardFormScreen(context, projectId: projectId),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TABLEROS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                    Icon(Icons.add, size: 14, color: scheme.outline),
                  ],
                ),
              ),
            ),
            if (boards.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(34, 0, 14, 6),
                child: Text(
                  'Ninguno. Pedíselo a un agente del proyecto.',
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ),
            for (final board in boards)
              _BoardRow(
                board: board,
                running: state.running.contains(board.id),
                lastRun: state.runs[board.id]?.firstOrNull,
                selected: board.id == selectedBoardId,
                onTap: () => onSelect(board.id),
              ),
          ],
        );
      },
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.board,
    required this.running,
    required this.lastRun,
    required this.selected,
    required this.onTap,
  });

  final Board board;
  final bool running;
  final BoardRun? lastRun;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.fromLTRB(34, 4, 10, 4),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                board.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? scheme.onSurface : scheme.outline,
                ),
              ),
            ),
            if (running)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: scheme.primary,
                ),
              )
            else if (lastRun != null)
              Icon(
                lastRun!.ok ? Icons.check : Icons.close,
                size: 12,
                color: lastRun!.ok ? scheme.tertiary : scheme.error,
              ),
          ],
        ),
      ),
    );
  }
}
