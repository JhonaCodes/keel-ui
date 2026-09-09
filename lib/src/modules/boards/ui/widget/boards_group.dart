import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/sidebar_section_row.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/modules/boards/ui/screen/board_form_screen.dart';
import 'package:keel_ui/src/modules/boards/ui/widget/delete_board_dialog.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// La sección Tableros de un proyecto, en el sidebar.
///
/// Hermana de Estado y de Sesiones, escrita con el mismo widget que ellas: un
/// tablero prueba la API de ESTE repo, así que vive en el proyecto y al mismo
/// nivel que lo demás que el proyecto tiene.
///
/// Sin texto de «todavía no hay ninguno»: esa explicación ocupaba cuatro
/// líneas de menú para decir que no había nada. Vive donde se puede hacer
/// algo con ella, que es la pantalla.
class BoardsSection extends StatelessWidget {
  const BoardsSection({
    super.key,
    required this.projectId,
    required this.workspace,
    required this.expanded,
    required this.onToggle,
  });

  final String projectId;
  final WorkspaceState workspace;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<BoardsViewModel, BoardsState>(
      viewmodel: BoardsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final boards = state.forProject(projectId);
        final navigator = WorkspaceService.instance.notifier;
        final onList = workspace.lens == WorkspaceLens.boards;
        final onOne = workspace.lens == WorkspaceLens.board;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SidebarSectionRow(
              label: AppLocalizations.of(context).sidebarSectionBoards,
              selected: onList,
              expanded: expanded,
              onToggle: onToggle,
              onTap: () => navigator.openBoards(projectId),
              trailing: SidebarCount(boards.length, highlight: onOne),
            ),
            if (expanded)
              for (final board in boards)
                _BoardRow(
                  board: board,
                  running: state.running.contains(board.id),
                  lastRun: state.runs[board.id]?.firstOrNull,
                  selected: onOne && board.id == workspace.boardId,
                  onTap: () => navigator.openBoard(board.id),
                ),
            if (expanded && boards.isEmpty)
              SidebarAddRow(
                label: AppLocalizations.of(context).sidebarNewBoard,
                onTap: () => openBoardFormScreen(context, projectId: projectId),
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
        padding: const EdgeInsets.fromLTRB(42, 3, 6, 3),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 6,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            const SizedBox(width: 7),
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
            const SizedBox(width: 4),
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
            // La misma cruz que cierra una sesión, en el mismo lugar: borrar
            // un tablero se hacía solo desde el banco, que es el sitio al que
            // no entrás cuando el que sobra lo tenés adelante.
            IconButton(
              tooltip: AppLocalizations.of(context).sidebarTooltipDeleteBoard,
              icon: const Icon(Icons.close, size: 13),
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              padding: EdgeInsets.zero,
              // Sin esto el botón reclama 48 puntos de alto —la medida de un
              // dedo— y la fila entera pasa de 30 a 54: tres tableros y tres
              // sesiones se comían media pantalla de menú por seis cruces.
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => confirmAndDeleteBoard(context, board),
            ),
          ],
        ),
      ),
    );
  }
}
