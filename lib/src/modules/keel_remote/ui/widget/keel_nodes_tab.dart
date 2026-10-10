import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_node.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_nodes_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// «Nodos»: every node enrolled with the server, and which are online.
class KeelNodesTab extends StatefulWidget {
  const KeelNodesTab({super.key});

  @override
  State<KeelNodesTab> createState() => _KeelNodesTabState();
}

class _KeelNodesTabState extends State<KeelNodesTab> {
  @override
  void initState() {
    super.initState();
    KeelNodesService.instance.notifier.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<KeelNodesViewModel, KeelNodesState>(
      viewmodel: KeelNodesService.instance.notifier,
      build: (state, viewmodel, keep) {
        final failure = state.failure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeelTabToolbar(onRefresh: viewmodel.refresh),
            KeelLoadingBar(loading: state.loading),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  if (failure != null) KeelFailureText(failure: failure),
                  if (state.nodes.isEmpty && !state.loading)
                    KeelEmptyText(
                      text: AppLocalizations.of(context).keelApiNodesEmpty,
                    ),
                  for (final node in state.nodes) _NodeTile(node: node),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node});

  final KeelNode node;

  void _openChat(BuildContext context) {
    Navigator.of(context).pop();
    WorkspaceService.instance.notifier.openServerChat(node.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Icon(
            node.isServer ? Icons.dns_outlined : Icons.laptop_mac_outlined,
            size: 22,
          ),
          KeelOnlineDot(online: node.online),
        ],
      ),
      title: Text(node.displayName),
      subtitle: Text(node.statusLine(t, DateTime.now())),
      trailing: node.isServer && node.online
          ? TextButton.icon(
              onPressed: () => _openChat(context),
              icon: const Icon(Icons.forum_outlined, size: 16),
              label: Text(t.keelApiNodeChat),
            )
          : null,
    );
  }
}
