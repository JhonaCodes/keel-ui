import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/screen/mcp_server_form_screen.dart';

/// Toggle-chip picker over the registered external MCP servers. This is
/// what makes the config SAY which integrations an agent carries.
class McpServerMultiSelect extends StatelessWidget {
  const McpServerMultiSelect({
    super.key,
    required this.selectedNames,
    required this.onChanged,
  });

  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String name, bool selected) {
    if (selected) {
      onChanged([...selectedNames, name]);
    } else {
      onChanged(selectedNames.where((entry) => entry != name).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Integraciones MCP',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openMcpServerFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar MCP'),
            ),
          ],
        ),
        ReactiveViewModelBuilder<McpServersViewModel, McpServersState>(
          viewmodel: McpServersService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.servers.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.messageNoMcpServersRegistered),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final server in state.servers)
                  FilterChip(
                    label: Text(server.name),
                    selected: selectedNames.contains(server.name),
                    onSelected: (selected) => _toggle(server.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
