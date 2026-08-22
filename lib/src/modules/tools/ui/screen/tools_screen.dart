import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tool_form_screen.dart';
import 'package:keel_ui/src/modules/tools/ui/widget/tool_tile.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools registradas'),
        actions: [
          IconButton(
            tooltip: 'Registrar nueva',
            icon: const Icon(Icons.add),
            onPressed: () => openToolFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<ToolsViewModel, ToolsState>(
        viewmodel: ToolsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.tools.isEmpty) {
            return const Center(
              child: Text('Todavía no registraste ninguna tool.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.tools.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => ToolTile(tool: state.tools[index]),
          );
        },
      ),
    );
  }
}
