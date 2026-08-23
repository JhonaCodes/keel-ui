part of '../../git_worktree.dart';

/// El aviso de que esta carpeta no es el worktree principal.
///
/// Una franja de una línea arriba de lo que estés mirando —estado, tablero o
/// sesión—, porque la pregunta que contesta no es de ninguna de esas
/// pantallas en particular: es de dónde estás parado.
///
/// **No se ve nunca** salvo que de verdad estés en un worktree de al lado. Un
/// proyecto normal no paga ni un píxel por esto.
class WorktreeStrip extends StatefulWidget {
  const WorktreeStrip({super.key, required this.project});

  final Project project;

  @override
  State<WorktreeStrip> createState() => _WorktreeStripState();
}

class _WorktreeStripState extends State<WorktreeStrip> {
  Timer? _timer;

  WorktreeViewModel get _worktrees => WorktreeService.instance.notifier;

  @override
  void initState() {
    super.initState();
    _worktrees.watch(widget.project.workingDirectory);
    _timer = Timer.periodic(
      _kPlaceTtl,
      (_) => _worktrees.watch(widget.project.workingDirectory),
    );
  }

  @override
  void didUpdateWidget(WorktreeStrip old) {
    super.didUpdateWidget(old);
    if (old.project.workingDirectory != widget.project.workingDirectory) {
      _worktrees.watch(widget.project.workingDirectory);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<WorktreeViewModel, WorktreeState>(
      viewmodel: WorktreeService.instance.notifier,
      build: (state, viewmodel, keep) {
        final place = state.places[widget.project.workingDirectory.trim()];
        if (place == null || !place.isLinked) return const SizedBox.shrink();
        return _Strip(project: widget.project, place: place);
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.project, required this.place});

  final Project project;
  final WorktreePlace place;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branch = place.branch;
    final root = place.main?.name ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => openWorktreePanel(context, project),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.alt_route, size: 14, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Worktree aparte'),
                          if (branch.isNotEmpty) ...[
                            const TextSpan(text: ' · rama '),
                            TextSpan(
                              text: branch,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: scheme.onSurface,
                              ),
                            ),
                          ] else
                            const TextSpan(text: ' · sin rama (HEAD suelto)'),
                          if (root.isNotEmpty) ...[
                            const TextSpan(text: ' · el principal es '),
                            TextSpan(
                              text: root,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => openWorktreePanel(context, project),
                    // El tamaño va en el Text y no en `styleFrom`: ahí
                    // REEMPLAZA el estilo del tema en vez de mezclarse, y con
                    // él se va la tipografía de la app.
                    child: const Text(
                      'Unificar',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
