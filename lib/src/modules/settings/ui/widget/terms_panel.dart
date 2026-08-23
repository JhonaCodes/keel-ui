import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/settings/model/keel_about.dart';
import 'package:keel_ui/src/modules/settings/model/keel_terms.dart';

/// Abre los términos de uso.
///
/// Panel y no diálogo: son diez secciones que se leen, y un diálogo con
/// scroll adentro es peor que una hoja. Se abre desde Ajustes y desde
/// cualquier otro lado que haga falta.
Future<void> openTermsPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const TermsPanel());
}

class TermsPanel extends StatelessWidget {
  const TermsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Términos de uso')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Keel',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            KeelTerms.version,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final section in KeelTerms.sections) ...[
            _TermsSectionView(section: section),
            const SizedBox(height: 20),
          ],
          const Divider(),
          const SizedBox(height: 16),
          Text(
            KeelAbout.copyright,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => openExternalUrl(KeelAbout.website),
              icon: const Icon(Icons.public, size: 18),
              label: const Text('jhonacode.com'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TermsSectionView extends StatelessWidget {
  const _TermsSectionView({required this.section});

  final TermsSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          section.body,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
