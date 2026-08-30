part of '../../catalog_bundle.dart';

/// Abre el panel de importar un paquete. Es el mismo para las tres cosas
/// que se pueden empaquetar: el manifiesto dice qué es.
Future<void> openBundleImportPanel(BuildContext context) => showFormPanel<void>(
  context,
  // Más ancho que un formulario: acá se leen fragmentos de código de otro,
  // y un script partido en ocho líneas de veinte caracteres no se lee.
  width: 860,
  child: const BundleImportPanel(),
);

/// Traer un paquete de otra persona: de dónde, qué trae, qué encontró la
/// revisión, y recién ahí instalarlo.
class BundleImportPanel extends StatefulWidget {
  const BundleImportPanel({super.key});

  @override
  State<BundleImportPanel> createState() => _BundleImportPanelState();
}

class _BundleImportPanelState extends State<BundleImportPanel> {
  final _link = TextEditingController();

  /// Que el usuario haya dicho que entiende lo que instala. Vive acá y no en
  /// el ViewModel porque no es del sistema: es de esta lectura, y cargar
  /// otro paquete tiene que volverlo a pedir.
  bool _understood = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<BundleViewModel, BundleState>(
      viewmodel: BundleService.instance.notifier,
      build: (state, viewmodel, keep) {
        final review = state.review;
        return Scaffold(
          appBar: AppBar(
            title: Text(t.actionImportPackage),
            actions: [
              if (review != null)
                IconButton(
                  tooltip: t.tooltipDismiss,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _understood = false);
                    viewmodel.discard();
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              if (review == null) ...[
                _Sources(
                  link: _link,
                  busy: state.busy,
                  onPickFile: viewmodel.pickAndReview,
                  onOpenLink: () => viewmodel.reviewFromLink(_link.text),
                ),
              ] else ...[
                _Cover(manifest: review.contents.manifest, source: state),
                const SizedBox(height: 18),
                _Brings(contents: review.contents),
                const SizedBox(height: 20),
                _SectionHead(
                  label: t.bundleSectionSecurityReview,
                  detail: review.audit.isClean
                      ? t.bundleNoFindings
                      : t.bundleFindingsCount(review.audit.findings.length),
                ),
                const SizedBox(height: 10),
                BundleFindingsView(audit: review.audit),
                const SizedBox(height: 18),
                _InstallBar(
                  audit: review.audit,
                  busy: state.busy,
                  understood: _understood,
                  onUnderstood: (value) =>
                      setState(() => _understood = value ?? false),
                  onInstall: () async {
                    await viewmodel.install();
                    if (mounted) setState(() => _understood = false);
                  },
                ),
              ],
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

class _Sources extends StatelessWidget {
  const _Sources({
    required this.link,
    required this.busy,
    required this.onPickFile,
    required this.onOpenLink,
  });

  final TextEditingController link;
  final bool busy;
  final VoidCallback onPickFile;
  final VoidCallback onOpenLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.bundleImportIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(
          t.bundleImportSafetyNote,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onPickFile,
              icon: const Icon(Icons.folder_open, size: 17),
              label: Text(t.actionChooseFile),
            ),
            const SizedBox(width: 14),
            Text(
              t.bundleOrFromLink,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: link,
                enabled: !busy,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: t.bundleLinkHint,
                ),
                onSubmitted: (_) => onOpenLink(),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onOpenLink,
              icon: const Icon(Icons.download_outlined, size: 17),
              label: Text(t.buttonBring),
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.manifest, required this.source});

  final BundleManifest manifest;
  final BundleState source;

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                manifest.kind.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: scheme.outline,
                ),
              ),
            ),
          ],
        ),
        if (manifest.summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(manifest.summary, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              source.source == BundleSource.link
                  ? Icons.link
                  : Icons.insert_drive_file_outlined,
              size: 13,
              color: scheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                source.sourceLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: scheme.outline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Brings extends StatelessWidget {
  const _Brings({required this.contents});

  final BundleContents contents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final secrets = contents.manifest.requiredSecrets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(label: t.bundleSectionWhatItBrings),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in contents.catalog.entries)
              if (entry.value.isNotEmpty)
                _Chip(
                  label: categoryLabel(entry.key),
                  count: entry.value.length,
                  names: [for (final json in entry.value) '${json['name']}'],
                ),
            if (contents.documentCount > 0)
              _Chip(
                label: t.bundleDocumentsLabel,
                count: contents.documentCount,
                names: const [],
              ),
          ],
        ),
        if (secrets.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.key_outlined, size: 16, color: scheme.outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.bundleSecretsRequiredNote(secrets.join(', ')),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// La categoría del catálogo, en palabras. Sale del mismo enum que usa el
/// respaldo: `profiles` es «Agentes» en los dos lados o en ninguno.
String categoryLabel(String category) =>
    BackupSection.byCategory(category)?.label ?? category;

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.names});

  final String label;
  final int count;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: names.isEmpty ? label : names.join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InstallBar extends StatelessWidget {
  const _InstallBar({
    required this.audit,
    required this.busy,
    required this.understood,
    required this.onUnderstood,
    required this.onInstall,
  });

  final BundleAudit audit;
  final bool busy;
  final bool understood;
  final ValueChanged<bool?> onUnderstood;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    // Con un hallazgo grave el botón no alcanza. No es una traba: es el
    // segundo que hace falta para leer lo de arriba, que es todo el punto
    // de haberlo listado.
    final needsAck = audit.hasHighRisk;
    final canInstall = !busy && (!needsAck || understood);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (needsAck)
          CheckboxListTile(
            value: understood,
            onChanged: busy ? null : onUnderstood,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              t.bundleHighRiskAck(audit.countAt(BundleRisk.alta)),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              const SizedBox(width: 12),
            ],
            FilledButton.icon(
              onPressed: canInstall ? onInstall : null,
              icon: const Icon(Icons.download_done_outlined, size: 17),
              label: Text(t.buttonInstall),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, this.detail = ''});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      letterSpacing: 1.2,
      color: scheme.outline,
    );
    return Row(
      children: [
        Text(label.toUpperCase(), style: style),
        const SizedBox(width: 8),
        Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        if (detail.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(detail, style: style),
        ],
      ],
    );
  }
}

class _Log extends StatelessWidget {
  const _Log({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 12, height: 1.45),
      ),
    );
  }
}
