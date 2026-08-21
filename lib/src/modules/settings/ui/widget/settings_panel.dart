import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
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
            ],
          );
        },
      ),
    );
  }
}
