import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_server_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/pending_secrets_badge.dart';

class McpServerTile extends StatelessWidget {
  const McpServerTile({super.key, required this.server});

  final McpServerConfig server;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar MCP'),
        content: Text(
          'Se eliminará "${server.name}". Los agentes que lo tenían asignado '
          'dejarán de recibir sus tools.',
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
    final detail = switch (server.transport) {
      McpTransport.stdio => '${server.command} ${server.args.join(' ')}'.trim(),
      McpTransport.http => server.url,
    };

    return ListTile(
      leading: Chip(
        label: Text(server.transport.label),
        visualDensity: VisualDensity.compact,
      ),
      title: Row(
        children: [
          Flexible(child: Text(server.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          PendingSecretsBadge(secretNames: server.secretNames),
        ],
      ),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openMcpServerFormScreen(context, initial: server),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
