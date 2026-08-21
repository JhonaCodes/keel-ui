import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tool_form_screen.dart';

class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool});

  final Tool tool;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tool'),
        content: Text(
          'Se eliminará la tool "${tool.name}". Los agentes que la tenían '
          'asignada dejarán de poder ejecutarla.',
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
      ToolsService.instance.notifier.deleteTool(tool.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Chip(
        label: Text(tool.runtime.label),
        visualDensity: VisualDensity.compact,
      ),
      title: Text(tool.name),
      subtitle: Text(
        tool.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openToolFormScreen(context, initial: tool),
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
