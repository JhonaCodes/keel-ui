import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_config_import_screen.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_server_form_screen.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/catalog_entry_card.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/installed_integration_card.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';

/// El catálogo de integraciones.
///
/// Antes esta pantalla era una lista que arrancaba diciéndote que no tenías
/// nada registrado, que es información que ya tenías. Lo que no te decía es
/// qué existe, cómo se configura y si lo que registraste levanta.
class McpServersScreen extends StatelessWidget {
  const McpServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integraciones'),
        actions: [
          TextButton.icon(
            onPressed: () => openMcpConfigImportScreen(context),
            icon: const Icon(Icons.content_paste_outlined, size: 16),
            label: const Text('Pegar config'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: () => openMcpServerFormScreen(context),
              child: const Text('Registrar a mano'),
            ),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<McpServersViewModel, McpServersState>(
        viewmodel: McpServersService.instance.notifier,
        build: (state, viewmodel, keep) {
          final installedCatalogIds = {
            for (final server in state.servers)
              if (server.catalogId.isNotEmpty) server.catalogId,
          };
          final available = mcpCatalogByCategory(
            excludingIds: installedCatalogIds,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _SectionHead(
                'Instaladas',
                first: true,
                trailing: state.servers.isEmpty
                    ? null
                    : '${state.servers.length}',
              ),
              if (state.servers.isEmpty)
                const _NothingInstalled()
              else
                for (final server in state.servers)
                  InstalledIntegrationCard(
                    server: server,
                    probe: state.probes[server.id],
                    probing: state.probing.contains(server.id),
                  ),
              for (final entry in available.entries) ...[
                _SectionHead('Disponibles · ${entry.key.label}'),
                _CatalogGrid(entries: entry.value),
              ],
              const SizedBox(height: 20),
              const _CatalogDisclaimer(),
            ],
          );
        },
      ),
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.entries});

  final List<McpCatalogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 96,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => CatalogEntryCard(
        entry: entries[index],
        onTap: () =>
            openMcpServerFormScreen(context, fromCatalog: entries[index]),
      ),
    );
  }
}

class _NothingInstalled extends StatelessWidget {
  const _NothingInstalled();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'Todavía ninguna. Elegí una de abajo, o pegá la configuración que '
        'publique el servidor que quieras usar.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// La honestidad del catálogo, escrita donde se lee.
class _CatalogDisclaimer extends StatelessWidget {
  const _CatalogDisclaimer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: scheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Estas fichas son una comodidad, no una promesa: los comandos y '
            'las URLs de los servidores de terceros cambian sin avisar. Cada '
            'una lleva su documentación oficial y todo queda editable; si '
            'quedó vieja, pegá la del servidor y esa gana.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
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
      padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 10),
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
