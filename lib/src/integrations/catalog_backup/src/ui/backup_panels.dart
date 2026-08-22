part of '../../catalog_backup.dart';

Future<void> openBackupExportPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const BackupExportPanel());
}

Future<void> openBackupImportPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const BackupImportPanel());
}

/// Elegir qué secciones viajan y a dónde. Los secrets son un opt-in aparte,
/// con su advertencia — "todo" nunca los incluye solo.
class BackupExportPanel extends StatefulWidget {
  const BackupExportPanel({super.key});

  @override
  State<BackupExportPanel> createState() => _BackupExportPanelState();
}

class _BackupExportPanelState extends State<BackupExportPanel> {
  final Set<BackupSection> _sections = {...BackupSection.values};
  bool _includeSecrets = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar respaldo')),
      body: ReactiveViewModelBuilder<CatalogBackupViewModel, CatalogBackupState>(
        viewmodel: CatalogBackupService.instance.notifier,
        build: (backup, viewmodel, keep) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Un solo archivo con lo que elijas. Las referencias van por '
                'nombre; las rutas de trabajo y las tareas nunca viajan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final section in BackupSection.values)
                CheckboxListTile(
                  value: _sections.contains(section),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(section.label),
                  onChanged: (checked) => setState(() {
                    checked ?? false
                        ? _sections.add(section)
                        : _sections.remove(section);
                  }),
                ),
              const Divider(height: 24),
              CheckboxListTile(
                value: _includeSecrets,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Incluir secrets (con sus VALORES)'),
                subtitle: const Text(
                  'El archivo los lleva en texto plano. Solo para llevarlos '
                  'a otra máquina tuya — nunca lo compartas.',
                ),
                onChanged: (checked) =>
                    setState(() => _includeSecrets = checked ?? false),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: backup.busy || _sections.isEmpty
                    ? null
                    : () => viewmodel.exportBackup(
                        sections: _sections,
                        includeSecrets: _includeSecrets,
                      ),
                icon: const Icon(Icons.save_alt, size: 18),
                label: const Text('Elegir destino y exportar'),
              ),
              if (backup.busy) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (backup.log.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  backup.log,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Importar mirando primero: se elige el archivo, se muestra qué trae y qué
/// pisaría, y recién ahí se aplica lo seleccionado.
class BackupImportPanel extends StatefulWidget {
  const BackupImportPanel({super.key});

  @override
  State<BackupImportPanel> createState() => _BackupImportPanelState();
}

class _BackupImportPanelState extends State<BackupImportPanel> {
  Set<BackupSection>? _sections;
  bool _includeSecrets = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar respaldo')),
      body: ReactiveViewModelBuilder<CatalogBackupViewModel, CatalogBackupState>(
        viewmodel: CatalogBackupService.instance.notifier,
        build: (backup, viewmodel, keep) {
          final preview = backup.preview;
          // Al cargar un archivo nuevo, arrancan elegidas las secciones que
          // el archivo trae.
          final selected = _sections ??= preview == null
              ? <BackupSection>{}
              : {...preview.sectionsPresent};

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              OutlinedButton.icon(
                onPressed: backup.busy
                    ? null
                    : () async {
                        await viewmodel.pickAndInspect();
                        setState(() => _sections = null);
                      },
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(
                  backup.loadedPath == null
                      ? 'Elegir archivo…'
                      : 'Archivo: ${backup.loadedPath!.split('/').last}',
                ),
              ),
              if (preview != null && preview.isEmpty) ...[
                const SizedBox(height: 12),
                const Text('El archivo no trae nada aplicable.'),
              ],
              if (preview != null && !preview.isEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Qué trae y qué pisa',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                for (final section in preview.sectionsPresent)
                  CheckboxListTile(
                    value: selected.contains(section),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      '${section.label}: '
                      '${preview.names[section]!.length} en el archivo, '
                      '${preview.conflicts[section]?.length ?? 0} pisan '
                      'existentes',
                    ),
                    subtitle: (preview.conflicts[section] ?? const []).isEmpty
                        ? null
                        : Text(
                            'Pisa: ${preview.conflicts[section]!.join(', ')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onChanged: (checked) => setState(() {
                      checked ?? false
                          ? selected.add(section)
                          : selected.remove(section);
                    }),
                  ),
                if (preview.knowledgeDocCounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Documentos de saber: '
                      '${preview.knowledgeDocCounts.entries.map((entry) => '${entry.key} (${entry.value})').join(', ')} '
                      '— van con la sección Bases de saber.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (preview.secretCount > 0) ...[
                  const Divider(height: 24),
                  CheckboxListTile(
                    value: _includeSecrets,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Aplicar ${preview.secretCount} secrets '
                      '(${preview.secretsWithValue} con valor)',
                    ),
                    subtitle: const Text(
                      'Crea los que falten y completa solo los pendientes — '
                      'un secret local con valor nunca se pisa.',
                    ),
                    onChanged: (checked) =>
                        setState(() => _includeSecrets = checked ?? false),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      backup.busy || (selected.isEmpty && !_includeSecrets)
                      ? null
                      : () => viewmodel.applyLoaded(
                          sections: selected,
                          includeSecrets: _includeSecrets,
                        ),
                  icon: const Icon(Icons.download_done, size: 18),
                  label: const Text('Aplicar lo seleccionado'),
                ),
              ],
              if (backup.busy) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (backup.log.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  backup.log,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
