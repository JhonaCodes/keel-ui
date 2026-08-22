import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/catalog_backup/catalog_backup.dart';
import 'package:keel_ui/src/integrations/jobs_api/jobs_api.dart';
import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';

Future<void> openSettingsPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const SettingsPanel());
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ReactiveViewModelBuilder<SettingsViewModel, AppSettings>(
        viewmodel: SettingsService.instance.notifier,
        build: (settings, viewmodel, keep) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Tamaño del texto',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.chatFontScale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 12,
                      label: '${(settings.chatFontScale * 100).round()}%',
                      onChanged: viewmodel.setChatFontScale,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${(settings.chatFontScale * 100).round()}%'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Permisos de escritura',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Leer archivos, buscarlos y consultar la web siempre está '
                'permitido. Acá decidís qué pueden modificar los agentes. '
                'Aplica a todos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              for (final tool in kAvailableExtraTools)
                CheckboxListTile(
                  value: settings.extraAllowedTools.contains(tool),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(tool),
                  onChanged: (enabled) =>
                      viewmodel.setExtraToolEnabled(tool, enabled ?? false),
                ),
              const SizedBox(height: 24),
              Text(
                'Respaldo del sistema',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Una carpeta tuya que hace de vault: adentro queda '
                '$kVaultBackupFileName con TODO el sistema (skills, reglas, '
                'tools, workflows, MCPs, agentes, estaciones, bases y '
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
              const SizedBox(height: 24),
              Text(
                'API de trabajos programados',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Para schedulers externos (cron, keel): '
                'POST /stations/<nombre>/tasks {"prompt": "..."} con el '
                'token Bearer. Solo loopback.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const _JobsApiInfo(),
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

/// La carpeta del vault: se elige con el diálogo del sistema, nunca se
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
                FilledButton.icon(
                  onPressed: vault.busy ? null : () => viewmodel.backup(),
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Respaldar'),
                ),
                FilledButton.tonalIcon(
                  onPressed: vault.busy
                      ? null
                      : () => viewmodel.backup(push: true),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Respaldar y subir'),
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
            if (vault.lastBackupAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Último respaldo: ${vault.lastBackupAt!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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

class _JobsApiInfo extends StatelessWidget {
  const _JobsApiInfo();

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<JobsApiViewModel, JobsApiState>(
      viewmodel: JobsApiService.instance.notifier,
      build: (api, viewmodel, keep) {
        if (!api.running) {
          return const Text('La API no está corriendo en esta ventana.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('URL: http://127.0.0.1:${api.port}'),
            const SizedBox(height: 4),
            SelectableText('Token: ${api.token}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: viewmodel.regenerateToken,
              icon: const Icon(Icons.autorenew, size: 18),
              label: const Text('Regenerar token'),
            ),
          ],
        );
      },
    );
  }
}
