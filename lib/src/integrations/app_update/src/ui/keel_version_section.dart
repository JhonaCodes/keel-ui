part of '../../app_update.dart';

/// La sección "Keel" de la pantalla de la Máquina: qué código tenés, qué hay
/// nuevo, y los dos botones.
///
/// Va ahí y no en Ajustes porque la pregunta es de la misma familia que las
/// otras tres de esa pantalla —qué CLIs hay instalados, cuánto se gastó, cómo
/// está el fierro—: cosas de ESTA máquina, no del trabajo.
class KeelVersionSection extends StatefulWidget {
  const KeelVersionSection({super.key});

  @override
  State<KeelVersionSection> createState() => _KeelVersionSectionState();
}

class _KeelVersionSectionState extends State<KeelVersionSection> {
  @override
  void initState() {
    super.initState();
    // Sin `force`: si ya se revisó al arrancar, abrir la pantalla no gasta
    // otro fetch.
    unawaited(AppUpdateService.instance.notifier.check());
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AppUpdateViewModel, AppUpdateState>(
      viewmodel: AppUpdateService.instance.notifier,
      build: (state, viewmodel, keep) {
        final plan = viewmodel.plan;
        final scheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHead(
              'Keel',
              first: true,
              trailing: state.version.branch.isEmpty
                  ? null
                  : state.version.branch,
            ),
            _Current(state: state),
            const SizedBox(height: 12),
            _Marked(
              plan.headline,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: state.pending ? scheme.onSurface : scheme.outline,
              ),
            ),
            if (state.version.incoming.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Incoming(commits: state.version.incoming),
            ],
            if (state.version.stale && !state.version.outdated) ...[
              const SizedBox(height: 10),
              _Advice(
                icon: Icons.build_outlined,
                tone: scheme.primary,
                text:
                    'Traer commits no cambia lo que está corriendo. Reconstruí '
                    'para pasarte al código que ya tenés en el disco.',
              ),
            ],
            for (final blocker in plan.blockers) ...[
              const SizedBox(height: 10),
              _Advice(icon: Icons.block, tone: scheme.error, text: blocker),
            ],
            if (state.report != null) ...[
              const SizedBox(height: 14),
              _Report(report: state.report!),
            ],
            const SizedBox(height: 14),
            _Actions(state: state, plan: plan),
          ],
        );
      },
    );
  }
}

/// El commit en el que está el repo y la fecha del binario abierto.
class _Current extends StatelessWidget {
  const _Current({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = state.version;

    if (!state.source.found) {
      return _Advice(
        icon: Icons.help_outline,
        tone: scheme.outline,
        text:
            'Esta copia corre desde `${Platform.resolvedExecutable}` y no hay '
            'un repo de Keel arriba de esa ruta.',
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                version.head.isEmpty ? '—' : version.head,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  version.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (version.at != null) 'código de ${_ago(version.at!)}',
              if (version.builtAt != null)
                'construido ${_ago(version.builtAt!)}',
              if (version.dirty) 'con cambios sin commitear',
            ].join('  ·  '),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: version.stale ? scheme.error : scheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            state.source.root,
            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Los commits que faltan, del más nuevo al más viejo.
class _Incoming extends StatelessWidget {
  const _Incoming({required this.commits});

  final List<KeelCommit> commits;

  /// Cuántos se listan. Con veinte, la lista deja de ser "qué cambió" y pasa
  /// a ser un `git log` adentro de una pantalla que no es para eso.
  static const _max = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final commit in commits.take(_max))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commit.sha,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    commit.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (commits.length > _max)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '…y ${commits.length - _max} más',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final KeelUpdateReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in report.steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (step.result) {
                    UpdateStepResult.ok => Icons.check,
                    UpdateStepResult.skipped => Icons.remove,
                    UpdateStepResult.failed => Icons.close,
                  },
                  size: 14,
                  color: switch (step.result) {
                    UpdateStepResult.ok => scheme.tertiary,
                    UpdateStepResult.skipped => scheme.outline,
                    UpdateStepResult.failed => scheme.error,
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
                            fontSize: 10.5,
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
        if (report.ok)
          _Advice(
            icon: Icons.build_outlined,
            tone: scheme.primary,
            text:
                'El código nuevo ya está en el disco. Lo que estás corriendo '
                'sigue siendo lo anterior hasta que reconstruyas.',
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.plan});

  final AppUpdateState state;
  final KeelUpdatePlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewmodel = AppUpdateService.instance.notifier;
    final busy = state.checking || state.updating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
              onPressed: busy ? null : () => viewmodel.check(force: true),
              child: const Text('Revisar'),
            ),
            if (plan.canRelaunch && (state.version.stale || state.report != null))
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt, size: 16),
                onPressed: busy ? null : viewmodel.relaunch,
                label: const Text('Reconstruir y reabrir'),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.download_outlined, size: 16),
              onPressed: busy || !plan.canRun ? null : viewmodel.update,
              label: Text(
                state.version.outdated
                    ? 'Traer ${state.version.behind} commits'
                    : 'Traer la versión nueva',
              ),
            ),
          ],
        ),
        if (!plan.canRelaunch && plan.source.found && plan.running > 0) ...[
          const SizedBox(height: 8),
          Text(
            plan.running == 1
                ? 'Reconstruir cierra Keel, y hay una sesión corriendo.'
                : 'Reconstruir cierra Keel, y hay ${plan.running} sesiones '
                      'corriendo.',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
        ],
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.label, {this.first = false, this.trailing});

  final String label;
  final bool first;
  final String? trailing;

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
      padding: EdgeInsets.only(top: first ? 0 : 26, bottom: 10),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: style),
          ],
        ],
      ),
    );
  }
}

class _Advice extends StatelessWidget {
  const _Advice({required this.icon, required this.text, required this.tone});

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

String _ago(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'recién';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
  return 'hace ${elapsed.inDays} d';
}
