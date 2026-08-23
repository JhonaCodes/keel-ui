import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/modules/boards/ui/screen/board_form_screen.dart';
import 'package:keel_ui/src/modules/boards/ui/widget/delete_board_dialog.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// Los tableros de un proyecto, en el área central.
///
/// Existe porque la sección no tenía a dónde llevarte: sin ninguno, el menú
/// gastaba cuatro líneas explicando que no había nada, y con la explicación
/// puesta ahí no había forma de hacer nada al respecto. Acá la falta de
/// tableros es una pantalla con los dos caminos a mano —a mano o pedido— y
/// el menú vuelve a ser una lista.
class ProjectBoardsView extends StatelessWidget {
  const ProjectBoardsView({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<BoardsViewModel, BoardsState>(
      viewmodel: BoardsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final boards = state.forProject(project.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(project: project, count: boards.length),
            const Divider(height: 1),
            Expanded(
              child: boards.isEmpty
                  ? _Empty(project: project)
                  : _Grid(boards: boards, state: state),
            ),
          ],
        );
      },
    );
  }
}

/// Lo que se le pide a Keel AI cuando apretás el botón. Nombra el proyecto y
/// su carpeta porque el asistente puede leerla: sin eso la primera respuesta
/// sería una pregunta.
String boardRequestFor(Project project) =>
    'Armá un tablero para el proyecto "${project.name}". Mirá su código en '
    '${project.workingDirectory} para saber qué endpoints tiene, proponeme '
    'uno concreto que me sirva para probar, y creámelo.';

class _Header extends StatelessWidget {
  const _Header({required this.project, required this.count});

  final Project project;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '#',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(project.name, style: text.titleMedium),
                    const SizedBox(width: 8),
                    Text(
                      'tableros',
                      style: TextStyle(fontSize: 13, color: scheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'Ninguno todavía'
                      : '$count ${count == 1 ? 'tablero' : 'tableros'}',
                  style: TextStyle(fontSize: 11.5, color: scheme.outline),
                ),
              ],
            ),
          ),
          if (count > 0)
            OutlinedButton.icon(
              onPressed: () =>
                  openBoardFormScreen(context, projectId: project.id),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo'),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 30, color: scheme.outline),
              const SizedBox(height: 16),
              Text(
                'Este proyecto todavía no tiene tableros',
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Un tablero es una pantallita para disparar algo contra tu '
                'propia app: lanzar una oferta, mandarte un push, pegarle a '
                'un endpoint que estás escribiendo.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              // Wrap y no Row: los dos botones son largos y esta pantalla
              // vive en el área central, que se angosta cuando abrís un
              // panel al lado.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    // El camino corto: el agente lee el repo y lo arma solo.
                    onPressed: () => AssistantWindowBridge.instance.openAsking(
                      boardRequestFor(project),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Pedírselo a Keel AI'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        openBoardFormScreen(context, projectId: project.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Crearlo a mano'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.boards, required this.state});

  final List<Board> boards;
  final BoardsState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final board in boards)
              _BoardCard(
                board: board,
                running: state.running.contains(board.id),
                lastRun: state.runs[board.id]?.firstOrNull,
              ),
          ],
        ),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.board,
    required this.running,
    required this.lastRun,
  });

  final Board board;
  final bool running;
  final BoardRun? lastRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final campos = board.fields.length;
    final acciones = board.actions.length;

    return SizedBox(
      width: 268,
      child: InkWell(
        onTap: () => WorkspaceService.instance.notifier.openBoard(board.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      board.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (running)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: scheme.primary,
                      ),
                    )
                  else if (lastRun != null)
                    Icon(
                      lastRun!.ok ? Icons.check : Icons.close,
                      size: 14,
                      color: lastRun!.ok ? scheme.tertiary : scheme.error,
                    ),
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 26,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        openBoardFormScreen(context, initial: board),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline, size: 15),
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 26,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => confirmAndDeleteBoard(context, board),
                  ),
                ],
              ),
              if (board.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  board.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: scheme.outline),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$campos ${campos == 1 ? 'campo' : 'campos'} · '
                    '$acciones ${acciones == 1 ? 'acción' : 'acciones'}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: scheme.outline,
                    ),
                  ),
                  if (board.actions.any((action) => action.runsCommands)) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Corre comandos en tu máquina',
                      child: Icon(
                        Icons.terminal_outlined,
                        size: 13,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
