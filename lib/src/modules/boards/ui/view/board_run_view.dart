import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/modules/boards/ui/screen/board_form_screen.dart';
import 'package:keel_ui/src/modules/boards/ui/widget/board_field_input.dart';
import 'package:keel_ui/src/modules/boards/ui/widget/board_response_pane.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';

/// El tablero, andando.
///
/// Campos arriba, botones en el medio, respuesta abajo. No tiene más
/// estructura que esa a propósito: es un instrumento, y un instrumento con
/// pestañas deja de ser un instrumento.
class BoardRunView extends StatefulWidget {
  const BoardRunView({super.key, required this.boardId});

  final String boardId;

  @override
  State<BoardRunView> createState() => _BoardRunViewState();
}

class _BoardRunViewState extends State<BoardRunView> {
  /// Lo que escribiste, por clave. Vive acá y no en el modelo: es de esta
  /// sesión de trabajo, no del tablero.
  final Map<String, String> _values = {};

  /// Las acciones con comando que ya confirmaste en esta corrida de la app.
  /// Se pregunta una vez por acción, no una vez por disparo: la segunda vez
  /// ya sabés lo que hace, y un diálogo que aparece siempre se aprieta sin
  /// leer.
  final Set<String> _confirmed = {};

  String? _lastRunId;
  String? _boardIdOfValues;

  /// Rellena con los valores por defecto la primera vez, y de nuevo si
  /// cambiás de tablero sin salir de la vista.
  void _seedIfNeeded(Board board) {
    if (_boardIdOfValues == board.id) return;
    _boardIdOfValues = board.id;
    _values
      ..clear()
      ..addEntries([
        for (final field in board.fields)
          MapEntry(field.key, field.defaultValue),
      ]);
    _lastRunId = null;
  }

  Future<bool> _confirmCommands(
    BuildContext context,
    BoardAction action,
  ) async {
    if (_confirmed.contains(action.id)) return true;

    final commands = [
      for (final step in action.steps)
        if (step.kind == BoardStepKind.comando) step.preview,
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${action.label}" corre comandos en tu máquina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Antes de la primera vez conviene leerlos. Después no se '
              'vuelve a preguntar por esta acción.',
            ),
            const SizedBox(height: 14),
            for (final command in commands)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText(
                  command,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Correr'),
          ),
        ],
      ),
    );

    if (ok ?? false) {
      _confirmed.add(action.id);
      return true;
    }
    return false;
  }

  Future<void> _run(Board board, BoardAction action) async {
    if (action.runsCommands && !await _confirmCommands(context, action)) {
      return;
    }
    final run = await BoardsService.instance.notifier.run(
      board.id,
      action.id,
      Map.of(_values),
    );
    if (!mounted || run == null) return;
    setState(() => _lastRunId = run.id);
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<BoardsViewModel, BoardsState>(
      viewmodel: BoardsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final board = viewmodel.boardById(widget.boardId);
        if (board == null) {
          return const Center(child: Text('Ese tablero ya no existe.'));
        }
        _seedIfNeeded(board);

        final runs = state.runs[board.id] ?? const <BoardRun>[];
        final last = _lastRunId == null
            ? runs.firstOrNull
            : runs.where((run) => run.id == _lastRunId).firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Head(board: board),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (board.note.isNotEmpty) ...[
                      Text(
                        board.note,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (board.fields.isNotEmpty) ...[
                      const _SectionHead('Qué mandás', first: true),
                      for (final field in board.fields)
                        BoardFieldInput(
                          field: field,
                          value: _values[field.key] ?? '',
                          onChanged: (value) =>
                              setState(() => _values[field.key] = value),
                        ),
                    ],
                    const _SectionHead('Qué disparás'),
                    _Actions(
                      board: board,
                      running: state.running.contains(board.id),
                      onRun: (action) => _run(board, action),
                      lastAt: runs.firstOrNull?.at,
                    ),
                    if (last != null) BoardResponsePane(run: last),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final author = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.id == board.createdByProfileId)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(board.name, style: theme.textTheme.titleMedium),
                Text(
                  author == null
                      ? 'lo hiciste vos'
                      : 'lo escribió @${author.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => openBoardFormScreen(context, initial: board),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.board,
    required this.running,
    required this.onRun,
    required this.lastAt,
  });

  final Board board;
  final bool running;
  final ValueChanged<BoardAction> onRun;
  final DateTime? lastAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in board.actions)
                FilledButton.icon(
                  onPressed: running ? null : () => onRun(action),
                  icon: Icon(
                    action.runsCommands
                        ? Icons.terminal_outlined
                        : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(action.label),
                ),
            ],
          ),
        ),
        if (running)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          )
        else if (lastAt != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'última corrida ${_ago(lastAt!)}',
              style: TextStyle(fontSize: 11.5, color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

String _ago(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'recién';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
  return 'hace ${elapsed.inDays} d';
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.label, {this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 22, bottom: 12),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.2,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
