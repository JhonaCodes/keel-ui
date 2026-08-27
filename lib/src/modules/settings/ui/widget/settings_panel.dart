import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/jobs_api/jobs_api.dart';
import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/screen/catalog_locks_screen.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/model/keel_about.dart';
import 'package:keel_ui/src/modules/settings/ui/widget/terms_panel.dart';
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
              _LanguageField(language: settings.language),
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
                'API de trabajos programados',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Para schedulers externos (cron, keel): '
                'POST /projects/<nombre>/tasks {"prompt": "..."} con el '
                'token Bearer. Solo loopback.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const _JobsApiInfo(),
              const SizedBox(height: 24),
              Text(
                'Elementos bloqueados',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Lo que un agente no puede cambiar ni borrar sin pedirte '
                'permiso primero. El candado se pone desde cada ítem; acá se '
                'ven todos juntos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => openCatalogLocksPanel(context),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Ver bloqueados…'),
                ),
              ),
              const SizedBox(height: 32),
              const _AboutKeel(),
            ],
          );
        },
      ),
    );
  }
}

/// Selector de idioma. `language` vacío sigue el idioma del sistema
/// operativo — no hay una opción explícita para eso en el dropdown porque
/// "Español (Colombia)"/"English" ya cubren el par soportado.
class _LanguageField extends StatelessWidget {
  final String language;

  const _LanguageField({required this.language});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Vacío = sigue el idioma del sistema: el dropdown muestra lo que
    // Flutter ya resolvió para esta ventana, no un valor inventado.
    final resolved = language.isEmpty
        ? Localizations.localeOf(context).languageCode
        : language;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        t.settingLanguage,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      trailing: DropdownButton<String>(
        value: resolved.startsWith('es') ? 'es_CO' : 'en',
        items: [
          DropdownMenuItem(value: 'es_CO', child: Text(t.languageSpanish)),
          DropdownMenuItem(value: 'en', child: Text(t.languageEnglish)),
        ],
        onChanged: (value) {
          if (value == null) return;
          SettingsService.instance.notifier.setLanguage(value);
        },
      ),
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

/// Quién hizo esto, dónde se habla de esto, y con qué permiso se usa.
///
/// El aviso de licencia va acá y no escondido en un archivo del repositorio
/// porque es lo único que ve quien recibe la app compilada: el `LICENSE` lo
/// lee quien clona, y quien clona no es a quien hay que avisarle.
class _AboutKeel extends StatelessWidget {
  const _AboutKeel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text('Acerca de Keel', style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _AboutLink(
              icon: Icons.forum_outlined,
              label: 'Comunidad en Discord',
              url: KeelAbout.community,
            ),
            const _AboutLink(
              icon: Icons.public,
              label: 'jhonacode.com',
              url: KeelAbout.website,
            ),
            OutlinedButton.icon(
              onPressed: () => openTermsPanel(context),
              icon: const Icon(Icons.gavel_outlined, size: 18),
              label: const Text('Términos de uso'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          KeelAbout.copyright,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          KeelAbout.licenseNotice,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => openExternalUrl(url),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
