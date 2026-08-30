part of '../../catalog_bundle.dart';

/// Abre el panel de exportar. Prepara el paquete y lo muestra ANTES de
/// escribir nada.
Future<void> openBundleExportPanel(
  BuildContext context,
  BundleKind kind,
  String name,
) {
  unawaited(BundleService.instance.notifier.prepare(kind, name));
  return showFormPanel<void>(
    context,
    width: 860,
    child: const BundleExportPanel(),
  );
}

/// Qué se lleva el paquete, qué le falta, y qué va a ver el que lo reciba.
class BundleExportPanel extends StatelessWidget {
  const BundleExportPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<BundleViewModel, BundleState>(
      viewmodel: BundleService.instance.notifier,
      build: (state, viewmodel, keep) {
        final draft = state.draft;
        return Scaffold(
          appBar: AppBar(title: Text(t.actionExportPackage)),
          body: draft == null
              ? Center(
                  child: state.busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            state.log.isEmpty
                                ? t.bundleExportNothingYet
                                : state.log,
                            textAlign: TextAlign.center,
                          ),
                        ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    _DraftCover(manifest: draft.manifest),
                    const SizedBox(height: 18),
                    _SectionHead(label: t.bundleSectionWhatItTakes),
                    const SizedBox(height: 10),
                    _CountChips(counts: draft.closure.counts),
                    if (draft.closure.missing.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Note(
                        icon: Icons.link_off,
                        // No es un error: un perfil puede nombrar una skill
                        // que borraste. Pero del otro lado va a faltar
                        // igual, y en silencio sería peor.
                        text: t.bundleMissingNote(
                          draft.closure.missing.map((m) => '· $m').join('\n'),
                        ),
                      ),
                    ],
                    if (draft.manifest.requiredSecrets.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Note(
                        icon: Icons.key_outlined,
                        text: t.bundleSecretsToCreateNote(
                          draft.manifest.requiredSecrets.join(', '),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _SectionHead(
                      label: t.bundleSectionWhatRecipientSees,
                      detail: draft.audit.isClean
                          ? t.bundleNoFindings
                          : t.bundleFindingsCount(draft.audit.findings.length),
                    ),
                    const SizedBox(height: 10),
                    BundleFindingsView(audit: draft.audit),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (state.busy) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          ),
                          const SizedBox(width: 12),
                        ],
                        FilledButton.icon(
                          onPressed: state.busy ? null : viewmodel.writeDraft,
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 17,
                          ),
                          label: Text(t.actionSaveZip),
                        ),
                      ],
                    ),
                    if (state.log.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Log(text: state.log),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _DraftCover extends StatelessWidget {
  const _DraftCover({required this.manifest});

  final BundleManifest manifest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(manifest.name, style: theme.textTheme.titleMedium),
            const SizedBox(width: 10),
            Text(
              manifest.kind.label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: scheme.outline,
              ),
            ),
          ],
        ),
        if (manifest.summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(manifest.summary, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _CountChips extends StatelessWidget {
  const _CountChips({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in counts.entries)
          _Chip(
            label: categoryLabel(entry.key),
            count: entry.value,
            names: const [],
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
