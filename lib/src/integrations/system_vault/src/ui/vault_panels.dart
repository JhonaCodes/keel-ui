part of '../../system_vault.dart';

Future<void> openVaultRestorePanel(BuildContext context) {
  return showFormPanel<void>(context, child: const VaultRestorePanel());
}

Future<void> openVaultClonePanel(BuildContext context) {
  return showFormPanel<void>(context, child: const VaultClonePanel());
}

/// Restaurar mirando primero: se lee el zip del vault, se muestra qué trae y
/// qué pisaría, y recién ahí se aplica lo elegido.
class VaultRestorePanel extends StatefulWidget {
  const VaultRestorePanel({super.key});

  @override
  State<VaultRestorePanel> createState() => _VaultRestorePanelState();
}

class _VaultRestorePanelState extends State<VaultRestorePanel> {
  Set<BackupSection>? _sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurar desde el vault')),
      body: ReactiveViewModelBuilder<SystemVaultViewModel, SystemVaultState>(
        viewmodel: SystemVaultService.instance.notifier,
        build: (vault, viewmodel, keep) {
          final preview = vault.preview;
          final selected = _sections ??= {...?preview?.sectionsPresent};

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Lee el $kVaultBackupFileName que hay en la carpeta del '
                'vault. Nada se aplica hasta que lo confirmes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: vault.busy
                    ? null
                    : () async {
                        await viewmodel.inspectVault();
                        setState(() => _sections = null);
                      },
                icon: const Icon(Icons.folder_zip_outlined, size: 18),
                label: const Text('Leer el respaldo'),
              ),
              _VaultPreview(
                preview: preview,
                selected: selected,
                busy: vault.busy,
                onToggle: (section, checked) => setState(() {
                  if (checked) {
                    selected.add(section);
                    return;
                  }
                  selected.remove(section);
                }),
                onApply: () => viewmodel.applyLoaded(sections: selected),
              ),
              _VaultStatus(state: vault),
            ],
          );
        },
      ),
    );
  }
}

/// El camino de una instalación nueva: traer el repo del vault y restaurar
/// desde él, sin haber configurado nada antes.
class VaultClonePanel extends StatefulWidget {
  const VaultClonePanel({super.key});

  @override
  State<VaultClonePanel> createState() => _VaultClonePanelState();
}

class _VaultClonePanelState extends State<VaultClonePanel> {
  final TextEditingController _url = TextEditingController();
  String _destination = '';
  Set<BackupSection>? _sections;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickDestination() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Usar esta carpeta',
    );
    if (path == null) return;
    setState(() => _destination = path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clonar vault')),
      body: ReactiveViewModelBuilder<SystemVaultViewModel, SystemVaultState>(
        viewmodel: SystemVaultService.instance.notifier,
        build: (vault, viewmodel, keep) {
          final preview = vault.preview;
          final selected = _sections ??= {...?preview?.sectionsPresent};
          final ready = _url.text.trim().isNotEmpty && _destination.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Trae el repo del vault a una carpeta vacía, la adopta como '
                'vault de esta máquina y te muestra qué trae el respaldo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'URL del repo del vault',
                  hintText: 'git@github.com:usuario/keel-knowledge-bases.git',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: vault.busy ? null : _pickDestination,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(
                  _destination.isEmpty
                      ? 'Elegir carpeta destino…'
                      : 'Destino: $_destination',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: vault.busy || !ready
                    ? null
                    : () async {
                        await viewmodel.cloneAndInspect(
                          url: _url.text,
                          destination: _destination,
                        );
                        setState(() => _sections = null);
                      },
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Clonar y leer'),
              ),
              _VaultPreview(
                preview: preview,
                selected: selected,
                busy: vault.busy,
                onToggle: (section, checked) => setState(() {
                  if (checked) {
                    selected.add(section);
                    return;
                  }
                  selected.remove(section);
                }),
                onApply: () => viewmodel.applyLoaded(sections: selected),
              ),
              _VaultStatus(state: vault),
            ],
          );
        },
      ),
    );
  }
}

/// Qué trae el respaldo leído y qué pisaría, con el botón de aplicar. Es la
/// misma pregunta en los dos caminos —restaurar y clonar—, así que es un
/// solo widget.
class _VaultPreview extends StatelessWidget {
  final BackupPreview? preview;
  final Set<BackupSection> selected;
  final bool busy;
  final void Function(BackupSection section, bool checked) onToggle;
  final VoidCallback onApply;

  const _VaultPreview({
    required this.preview,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    if (preview == null) return const SizedBox.shrink();
    if (preview.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('El respaldo no trae nada aplicable.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Qué trae y qué pisa',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final section in preview.sectionsPresent)
          _VaultSectionTile(
            section: section,
            preview: preview,
            checked: selected.contains(section),
            onChanged: (checked) => onToggle(section, checked),
          ),
        if (preview.knowledgeDocCounts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Documentos de saber en el zip: '
              '${preview.knowledgeDocCounts.entries.map((entry) => '${entry.key} (${entry.value})').join(', ')} '
              '— van con la sección Bases de saber. Las bases que viven '
              'dentro del vault ya llegaron con el repo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (preview.secretCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Se van a crear los ${preview.secretCount} secrets que el '
              'respaldo registra, SIN valor: los valores nunca viajan en el '
              'vault. Quedan pendientes de completar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : onApply,
          icon: const Icon(Icons.download_done, size: 18),
          label: const Text('Restaurar lo seleccionado'),
        ),
      ],
    );
  }
}

class _VaultSectionTile extends StatelessWidget {
  final BackupSection section;
  final BackupPreview preview;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _VaultSectionTile({
    required this.section,
    required this.preview,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final conflicts = preview.conflicts[section] ?? const <String>[];
    return CheckboxListTile(
      value: checked,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        '${section.label}: ${preview.names[section]!.length} en el respaldo, '
        '${conflicts.length} pisan existentes',
      ),
      subtitle: conflicts.isEmpty
          ? null
          : Text(
              'Pisa: ${conflicts.join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      onChanged: (value) => onChanged(value ?? false),
    );
  }
}

/// El hilandero mientras algo corre, y el resultado cuando terminó.
class _VaultStatus extends StatelessWidget {
  final SystemVaultState state;

  const _VaultStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (state.log.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(
              state.log,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
