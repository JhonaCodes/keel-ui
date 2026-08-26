import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/modules/boards/ui/screen/board_form_screen.dart';
import 'package:keel_ui/src/modules/boards/ui/widget/delete_board_dialog.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

/// El banco: todos los tableros, agrupados por proyecto.
///
/// El lugar donde se usan es el sidebar del proyecto. Este es para
/// ordenarlos: verlos todos juntos, renombrar, borrar lo que quedó de una
/// prueba de hace tres semanas.
class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key, required this.onOpen});

  /// Abrir un tablero cierra el panel: lo que se usa es el tablero, no la
  /// lista.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banco de pruebas')),
      body: ReactiveViewModelBuilder<BoardsViewModel, BoardsState>(
        viewmodel: BoardsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.boards.isEmpty) return const _Empty();

          final projects = ProjectsService.instance.notifier.data.projects;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              for (final project in projects)
                if (state.forProject(project.id) case final boards)
                  if (boards.isNotEmpty) ...[
                    _ProjectHead(name: project.name, count: boards.length),
                    for (final board in boards)
                      _BoardTile(
                        board: board,
                        projectName: project.name,
                        lastRun: state.runs[board.id]?.firstOrNull,
                        onOpen: () {
                          Navigator.of(context).pop();
                          onOpen(board.id);
                        },
                      ),
                  ],
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 28, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text('Todavía no hay tableros', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Un tablero es una pantallita para disparar algo contra tu '
              'propia app: lanzar una oferta, mandarte un push, pegarle a un '
              'endpoint que estás escribiendo.\n\n'
              'Lo más rápido es pedírselo a un agente del proyecto: lee tu '
              'código y lo arma solo. Aparece en la sección Tableros de ese '
              'proyecto.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectHead extends StatelessWidget {
  const _ProjectHead({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      letterSpacing: 1.2,
      color: scheme.outline,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(name.toUpperCase(), style: style),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
          const SizedBox(width: 8),
          Text('$count', style: style),
        ],
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({
    required this.board,
    required this.projectName,
    required this.lastRun,
    required this.onOpen,
  });

  final Board board;
  final String projectName;
  final BoardRun? lastRun;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final acciones = board.actions.length;
    final campos = board.fields.length;
    final lockName = catalogBoardLockName(projectName, board.name);
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.board,
      lockName,
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      title: Row(
        children: [
          Flexible(child: Text(board.name, overflow: TextOverflow.ellipsis)),
          if (board.actions.any((action) => action.runsCommands)) ...[
            const SizedBox(width: 8),
            Icon(Icons.terminal_outlined, size: 14, color: scheme.outline),
          ],
        ],
      ),
      subtitle: Text(
        '$campos ${campos == 1 ? 'campo' : 'campos'} · '
        '$acciones ${acciones == 1 ? 'acción' : 'acciones'}'
        '${lastRun == null ? '' : ' · última corrida ${lastRun!.ok ? 'ok' : 'con error'}'}',
        style: TextStyle(fontSize: 11.5, color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatalogLockButton(
            kind: CatalogLockKind.board,
            name: lockName,
            size: 18,
            compact: true,
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: isLocked
                ? null
                : () => openBoardFormScreen(context, initial: board),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: isLocked
                ? null
                : () => confirmAndDeleteBoard(context, board),
          ),
        ],
      ),
    );
  }
}
