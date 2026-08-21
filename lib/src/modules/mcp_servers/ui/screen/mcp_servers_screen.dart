import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_server_form_screen.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/mcp_server_tile.dart';

class McpServersScreen extends StatelessWidget {
  const McpServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integraciones MCP'),
        actions: [
          IconButton(
            tooltip: 'Registrar nueva',
            icon: const Icon(Icons.add),
            onPressed: () => openMcpServerFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<McpServersViewModel, McpServersState>(
        viewmodel: McpServersService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.servers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no registraste ningún MCP externo.\n\n'
                  'Acá se registran integraciones como gmail, drive o '
                  'github; después se asignan por agente en su formulario.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.servers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                McpServerTile(server: state.servers[index]),
          );
        },
      ),
    );
  }
}
