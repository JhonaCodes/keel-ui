part of '../../git_worktree.dart';

/// Abre el panel del worktree. Arma el plan mientras se desliza.
Future<void> openWorktreePanel(BuildContext context, Project project) async {
  unawaited(WorktreeService.instance.notifier.prepare(project));
  await showFormPanel<void>(
    context,
    width: 640,
    child: WorktreePanel(project: project),
  );
  WorktreeService.instance.notifier.forget();
}

/// Qué worktree es este, qué va a pasar si lo unificás, y qué pasó.
class WorktreePanel extends StatelessWidget {
  const WorktreePanel({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<WorktreeViewModel, WorktreeState>(
      viewmodel: WorktreeService.instance.notifier,
      build: (state, viewmodel, keep) {
        final plan = state.plan;
        final report = state.report;

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).tooltipWorktreeSeparate),
          ),
          body: switch ((plan, report)) {
            (_, final WorktreeUnifyReport done) => _Report(report: done),
            (final WorktreeUnifyPlan ready, _) => _Plan(
              plan: ready,
              project: project,
              busy: state.busy,
            ),
            _ => Center(
              child: state.busy
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Esta carpeta es el worktree principal del repo. No '
                        'hay nada que unificar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          },
        );
      },
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.plan, required this.project, required this.busy});

  final WorktreeUnifyPlan plan;
  final Project project;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _Marked(
          plan.headline,
          style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface),
        ),
        const SizedBox(height: 16),
        _Place(
          icon: Icons.alt_route,
          label: 'Acá',
          path: plan.from.path,
          branch: plan.branch,
          accent: true,
        ),
        const SizedBox(height: 8),
        _Place(
          icon: Icons.account_tree_outlined,
          label: 'El principal',
          path: plan.mainTree.path,
          branch: plan.mainTree.branch ?? '(HEAD suelto)',
        ),
        const SizedBox(height: 20),
        const _Head(label: 'Qué va a pasar'),
        const SizedBox(height: 8),
        for (final (index, step) in _steps(plan).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _Marked(
              '${index + 1}. $step',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (plan.ignoredHere.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Note(
            icon: Icons.delete_sweep_outlined,
            tone: scheme.primary,
            // Lo ignorado no sale en ningún `git status` y se borra igual.
            // Es el `.env` que escribiste a mano hace tres semanas.
            text:
                'Con la carpeta se van ${_files(plan.ignoredHere.length)} '
                'ignorados, que no están en git y no vuelven:\n'
                '${plan.ignoredHere.take(8).map((path) => '· $path').join('\n')}'
                '${plan.ignoredHere.length > 8 ? '\n· …y ${plan.ignoredHere.length - 8} más' : ''}',
          ),
        ],
        if (plan.behind > 0) ...[
          const SizedBox(height: 10),
          _Note(
            icon: Icons.trending_flat,
            tone: scheme.onSurfaceVariant,
            text:
                '`${plan.branch}` está ${plan.behind} commits detrás de '
                '`${plan.base}`. No los traigo: mezclar es una decisión tuya, '
                'y acá solo se muda la rama de carpeta.',
          ),
        ],
        for (final blocker in plan.blockers) ...[
          const SizedBox(height: 10),
          _Note(icon: Icons.block, tone: scheme.error, text: blocker),
        ],
        const SizedBox(height: 22),
        // Wrap y no Row: "Unificar en el principal" y "Volver a revisar" no
        // entran juntos en el ancho del panel, y un botón cortado por la
        // mitad es peor que uno en la línea de abajo.
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => WorktreeService.instance.notifier.prepare(project),
              child: const Text('Volver a revisar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.merge, size: 16),
              onPressed: busy || !plan.canRun
                  ? null
                  : () => WorktreeService.instance.notifier.unify(project),
              label: Text(AppLocalizations.of(context).actionUnifyInMain),
            ),
          ],
        ),
      ],
    );
  }
}

List<String> _steps(WorktreeUnifyPlan plan) => [
  if (plan.base.isEmpty)
    'No encontré `main` ni `master`, así que no traigo nada de afuera.'
  else if (!plan.hasRemote)
    'El repo no tiene `origin`, así que no hay de dónde traer `${plan.base}`.'
  else if (plan.mainTree.branch == plan.base)
    'Traigo `${plan.base}` de `origin` al worktree principal, que ya está '
        'parado ahí.'
  else
    'Adelanto `${plan.base}` con lo de `origin`, sin tocarle la copia de '
        'trabajo al principal.',
  'Saco `${plan.from.name}`: git desregistra el worktree y BORRA la carpeta '
      'del disco.',
  if (plan.branch.isNotEmpty)
    'Pongo `${plan.branch}` en el worktree principal, que recién ahora puede '
        'tomarla.',
  'Este proyecto pasa a correr en `${plan.mainTree.path}`, con la misma rama '
      'y el mismo hilo de sesiones.',
];

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final WorktreeUnifyReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _Marked(
          _closing(report),
          style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface),
        ),
        const SizedBox(height: 18),
        for (final step in report.steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (step.result) {
                    WorktreeStepResult.ok => Icons.check,
                    WorktreeStepResult.skipped => Icons.remove,
                    WorktreeStepResult.failed => Icons.close,
                  },
                  size: 14,
                  color: switch (step.result) {
                    WorktreeStepResult.ok => scheme.tertiary,
                    WorktreeStepResult.skipped => scheme.outline,
                    WorktreeStepResult.failed => scheme.error,
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Marked(
                        step.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (step.detail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        SelectableText(
                          step.detail,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (report.behind > 0) ...[
          const SizedBox(height: 6),
          _Note(
            icon: Icons.trending_flat,
            tone: scheme.onSurfaceVariant,
            text:
                'Te quedan ${report.behind} commits de la base sin traer. '
                'Mezclalos cuando quieras: `git merge` o `git rebase`, desde '
                'acá o desde una sesión.',
          ),
        ],
      ],
    );
  }
}

String _closing(WorktreeUnifyReport report) {
  if (!report.moved) {
    return 'No se tocó nada: la carpeta sigue donde estaba y el proyecto '
        'también.';
  }
  if (report.ok) {
    return 'Listo. `${report.branch}` está en el worktree principal y este '
        'proyecto ya corre ahí.';
  }
  return 'La carpeta se sacó y el proyecto pasó al principal, pero algo del '
      'camino falló. Los commits de `${report.branch}` están: la rama sigue '
      'existiendo.';
}

class _Place extends StatelessWidget {
  const _Place({
    required this.icon,
    required this.label,
    required this.path,
    required this.branch,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String path;
  final String branch;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent ? scheme.primary : scheme.outlineVariant,
          width: accent ? 1 : 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: accent ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        letterSpacing: 1.1,
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        branch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          color: accent ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(
                  path,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        letterSpacing: 1.2,
        color: scheme.outline,
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 9),
          Expanded(
            child: _Marked(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto con los `pedazos entre backticks` en monoespaciada.
///
/// Acá adentro casi todo lo que importa es un nombre exacto —una rama, una
/// ruta, un comando que hay que escribir— y mezclado con la prosa se pierde.
/// Marcarlo cuesta esto; dejar los backticks a la vista es peor que no
/// marcarlo.
class _Marked extends StatelessWidget {
  const _Marked(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = text.split('`');
    return Text.rich(
      TextSpan(
        children: [
          for (final (index, part) in parts.indexed)
            TextSpan(
              text: part,
              // Los impares son lo que estaba adentro de los backticks.
              style: index.isOdd
                  ? TextStyle(
                      fontFamily: 'monospace',
                      fontSize: style.fontSize! - 0.5,
                      color: scheme.onSurface,
                    )
                  : null,
            ),
        ],
      ),
      style: style,
    );
  }
}
