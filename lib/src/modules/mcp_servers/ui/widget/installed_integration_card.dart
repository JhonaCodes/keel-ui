import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_probe_result.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_server_form_screen.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/integration_glyph.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/probe_status.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/pending_secrets_badge.dart';

/// Una integración registrada, con lo que hace falta para saber si sirve:
/// cómo se conecta, si levanta, si le falta una clave y quién la usa.
///
/// Ese último dato es el que convierte la tarjeta en algo accionable: un MCP
/// registrado y asignado a nadie no le llega a ningún turno, y hasta ahora
/// eso no se veía en ninguna pantalla.
class InstalledIntegrationCard extends StatelessWidget {
  const InstalledIntegrationCard({
    super.key,
    required this.server,
    required this.probe,
    required this.probing,
  });

  final McpServerConfig server;
  final McpProbeResult? probe;
  final bool probing;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar integración'),
        content: Text(
          'Se elimina "${server.name}". Los agentes que la tenían asignada '
          'dejan de recibir sus tools.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      McpServersService.instance.notifier.deleteServer(server.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = mcpCatalogEntryFor(server.catalogId);

    final users = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.mcpServers.contains(server.name))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (entry != null)
            IntegrationGlyph.forEntry(entry)
          else
            IntegrationGlyph.forName(server.name),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        server.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Chip(server.transport.label),
                    const SizedBox(width: 8),
                    PendingSecretsBadge(secretNames: server.secretNames),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  users == 0
                      ? '${server.detail} · sin asignar a ningún agente'
                      : '${server.detail} · $users '
                            '${users == 1 ? 'agente' : 'agentes'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: ProbeStatus(result: probe, probing: probing),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: probing
                ? null
                : () => McpServersService.instance.notifier.probeServer(
                    server.id,
                  ),
            child: const Text('Probar'),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => openMcpServerFormScreen(context, initial: server),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}

/// El detalle del transporte, en el idioma de chip que usa el resto.
class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
