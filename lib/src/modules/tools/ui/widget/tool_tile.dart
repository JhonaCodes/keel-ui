import 'package:flutter/material.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tool_form_screen.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';

class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool});

  final Tool tool;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await confirmWithCard(
      context,
      title: 'Eliminar tool',
      body:
          'Se eliminará la tool "${tool.name}". Los agentes que la tenían '
          'asignada dejarán de poder ejecutarla.',
      destructive: true,
    );

    if (confirmed) {
      ToolsService.instance.notifier.deleteTool(tool.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.tool,
      tool.name,
    );
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
          CatalogLockButton(kind: CatalogLockKind.tool, name: tool.name),
          IconButton(
            tooltip: t.buttonEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: isLocked
                ? null
                : () => openToolFormScreen(context, initial: tool),
          ),
          IconButton(
            tooltip: t.buttonDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: isLocked ? null : () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
