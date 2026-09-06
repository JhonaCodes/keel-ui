part of '../../system_vault.dart';

/// La pantalla de Respaldo.
///
/// Existe porque «Respaldo» y «Ajustes» abrían literalmente la misma: los dos
/// botones del rail llamaban `openSettingsPanel(context)` sin argumentos, y
/// `SettingsPanel` no recibe ninguno, así que era imposible que difirieran.
/// Lo de respaldo quedaba enterrado a mitad del scroll de Configuración.
///
/// Acá vive todo lo que habla de sobrevivir a una desinstalación —el vault en
/// una carpeta versionada y la exportación a un archivo portable— y sale de
/// Configuración: el mismo control en dos lugares es lo que hace dudar cuál
/// es el bueno.
Future<void> openVaultPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const VaultPanel());
}

class VaultPanel extends StatelessWidget {
  const VaultPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo')),
      body: ReactiveViewModelBuilder<SettingsViewModel, AppSettings>(
        viewmodel: SettingsService.instance.notifier,
        build: (settings, viewmodel, keep) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Respaldo del sistema',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Una carpeta tuya que hace de vault: adentro queda '
                '$kVaultBackupFileName con TODO el sistema (skills, reglas, '
                'tools, workflows, MCPs, agentes, proyectos, bases y '
                'ajustes). Versionala con git y desinstalar la app deja de '
                'costarte nada. Los hilos de chat no entran, y de los '
                'secrets solo viajan los nombres.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _VaultFolderField(path: settings.vaultPath),
              const SizedBox(height: 8),
              _RepoUrlField(
                initialValue: settings.vaultRepoUrl,
                label: 'URL del repo del vault',
                onSubmitted: viewmodel.setVaultRepoUrl,
              ),
              const SizedBox(height: 8),
              const _SystemVaultControls(),
              const SizedBox(height: 24),
              Text(
                'Respaldo en un archivo',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Todo el catálogo (o las secciones que elijas) en un único '
                'archivo portable, con los documentos de las bases de saber '
                'locales. Es el único camino que lleva los VALORES de los '
                'secrets — el vault nunca los sube — y solo si los pedís '
                'explícitamente.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => openBackupExportPanel(context),
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Exportar…'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => openBackupImportPanel(context),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Importar…'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A settings text field that saves on submit/focus-out — the value must
/// come from and return to the ViewModel, never live only in the widget.
class _RepoUrlField extends StatefulWidget {
  const _RepoUrlField({
    required this.initialValue,
    required this.label,
    required this.onSubmitted,
  });

  final String initialValue;
  final String label;
  final ValueChanged<String> onSubmitted;

  @override
  State<_RepoUrlField> createState() => _RepoUrlFieldState();
}

class _RepoUrlFieldState extends State<_RepoUrlField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) widget.onSubmitted(_controller.text);
      },
      child: TextField(
        controller: _controller,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'git@github.com:usuario/repo.git',
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}

/// escribe a mano. Una ruta tipeada con un dedo de más es un respaldo que se
/// escribe en el lugar equivocado y parece haber funcionado.
class _VaultFolderField extends StatelessWidget {
  final String path;

  const _VaultFolderField({required this.path});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final chosen = await getDirectoryPath(
              confirmButtonText: 'Usar esta carpeta',
            );
            if (chosen == null) return;
            SettingsService.instance.notifier.setVaultPath(chosen);
          },
          icon: const Icon(Icons.folder_open, size: 18),
          label: Text(
            path.isEmpty ? 'Elegir carpeta del vault…' : 'Vault: $path',
          ),
        ),
        if (path.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sugerencia: ~/keel-knowledge-bases, la misma carpeta donde ya '
              'viven tus bases de saber locales — así un solo repo lleva el '
              'sistema y el conocimiento.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// todas las letras: un respaldo que solo existe en este disco no es un
/// respaldo contra perder este disco.
class _VaultWarning extends StatelessWidget {
  final String message;

  const _VaultWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemVaultControls extends StatelessWidget {
  const _SystemVaultControls();

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<SystemVaultViewModel, SystemVaultState>(
      viewmodel: SystemVaultService.instance.notifier,
      build: (vault, viewmodel, keep) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Un solo botón: un respaldo que se queda en este disco no
                // protege de perder este disco, y tenerlo al lado del que sí
                // sube hacía que la mitad barata pareciera terminada.
                FilledButton.icon(
                  onPressed: vault.busy ? null : () => viewmodel.backup(),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Subir a GitHub'),
                ),
                OutlinedButton.icon(
                  onPressed: vault.busy
                      ? null
                      : () => openVaultRestorePanel(context),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restaurar…'),
                ),
                OutlinedButton.icon(
                  onPressed: vault.busy
                      ? null
                      : () => openVaultClonePanel(context),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Clonar vault…'),
                ),
                if (vault.busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (vault.lastBackupAt != null)
                  'Último respaldo: ${vault.lastBackupAt!.toLocal()}.'
                else
                  'Todavía no subiste ninguno.',
                'Nada de esto corre solo: si no apretás el botón, no hay '
                    'respaldo.',
                if (vault.gitSizeKiB > 0)
                  'El repo del vault ocupa '
                      '${(vault.gitSizeKiB / 1024).toStringAsFixed(1)} MB: '
                      'cada respaldo REEMPLAZA al anterior, no se acumulan.',
              ].join(' '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (vault.warning != null) ...[
              const SizedBox(height: 8),
              _VaultWarning(message: vault.warning!),
            ],
            if (vault.log.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                vault.log,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}
