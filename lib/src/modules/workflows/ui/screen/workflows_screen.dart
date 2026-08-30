import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflow_form_screen.dart';
import 'package:keel_ui/src/modules/workflows/ui/widget/workflow_tile.dart';

class WorkflowsScreen extends StatelessWidget {
  const WorkflowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitleRegisteredWorkflows),
        actions: [
          IconButton(
            tooltip: t.tooltipImportPackage,
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => openBundleImportPanel(context),
          ),
          IconButton(
            tooltip: t.tooltipRegisterNew,
            icon: const Icon(Icons.add),
            onPressed: () => openWorkflowFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
        viewmodel: WorkflowsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.workflows.isEmpty) {
            return Center(child: Text(t.messageNoWorkflowsRegistered));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.workflows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                WorkflowTile(workflow: state.workflows[index]),
          );
        },
      ),
    );
  }
}
