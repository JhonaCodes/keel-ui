import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/keel_remote/model/desktop_node_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/desktop_node_viewmodel.dart';

/// «Esta PC como nodo»: connecting this PC to the Keel API as a node, how
/// its link is doing, and the way out.
class DesktopNodeCard extends StatelessWidget {
  const DesktopNodeCard({super.key, required this.signedIn});

  /// Connecting takes the person's session; disconnecting does not need it.
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<DesktopNodeViewModel, DesktopNodeState>(
      viewmodel: DesktopNodeService.instance.notifier,
      build: (node, viewmodel, keep) {
        if (!node.shownWith(signedIn: signedIn)) return const SizedBox.shrink();
        final t = AppLocalizations.of(context);
        final problem = node.problem;
        final failure = node.failure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeelSectionTitle(text: t.keelThisPcTitle),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NodeHeadline(node: node),
                    const SizedBox(height: 10),
                    if (node.isOn)
                      _NodeDetails(node: node)
                    else
                      _NodeIntro(text: t.keelThisPcIntro),
                    const SizedBox(height: 12),
                    KeelLoadingBar(loading: node.isBusy),
                    if (problem != null) _NodeProblem(problem: problem),
                    if (failure != null) KeelFailureText(failure: failure),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _NodeAction(
                        node: node,
                        signedIn: signedIn,
                        viewmodel: viewmodel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Whether this PC is a node now, as a dot and a word.
class _NodeHeadline extends StatelessWidget {
  const _NodeHeadline({required this.node});

  final DesktopNodeState node;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KeelOnlineDot(online: node.isOn),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            node.status.label(AppLocalizations.of(context)),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

/// What connecting means, while this PC is not taking tasks.
class _NodeIntro extends StatelessWidget {
  const _NodeIntro({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

/// The node's id, its last calls, the tasks it took, whether Keel AI runs
/// on it, its sessions with «Aceptar todo» on and its recent lines.
class _NodeDetails extends StatelessWidget {
  const _NodeDetails({required this.node});

  final DesktopNodeState node;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.keelThisPcNodeId(node.nodeId)),
        const SizedBox(height: 4),
        Text(node.pollLine(t, now)),
        const SizedBox(height: 4),
        Text(node.reportLine(t, now)),
        const SizedBox(height: 4),
        Text(t.keelThisPcTasksTaken(node.tasksTaken)),
        const SizedBox(height: 4),
        Text(node.keelAiLine(t)),
        if (node.autoApproved.isNotEmpty) ...[
          KeelSectionTitle(text: t.keelThisPcAutoApprove),
          for (final session in node.autoApproved)
            Text(session.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (node.recent.isNotEmpty) ...[
          KeelSectionTitle(text: t.keelThisPcRecent),
          for (final line in node.recent) _NodeLogRow(line: line, now: now),
        ],
      ],
    );
  }
}

/// One of the link's recent lines, in the error colour when it is one.
class _NodeLogRow extends StatelessWidget {
  const _NodeLogRow({required this.line, required this.now});

  final DesktopNodeLogLine line;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        line.line(now),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: line.isError ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// What went wrong on this PC's side, in the error colour.
class _NodeProblem extends StatelessWidget {
  const _NodeProblem({required this.problem});

  final DesktopNodeProblem problem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        problem.message(AppLocalizations.of(context)),
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// «Conectar esta PC como nodo», or «Desconectar» once it is one.
class _NodeAction extends StatelessWidget {
  const _NodeAction({
    required this.node,
    required this.signedIn,
    required this.viewmodel,
  });

  final DesktopNodeState node;
  final bool signedIn;
  final DesktopNodeViewModel viewmodel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (node.canDisconnect || node.status == DesktopNodeStatus.disconnecting) {
      return OutlinedButton.icon(
        onPressed: node.canDisconnect ? viewmodel.disconnect : null,
        icon: const Icon(Icons.link_off, size: 16),
        label: Text(t.keelThisPcDisconnect),
      );
    }
    return FilledButton.icon(
      onPressed: signedIn && node.canConnect ? viewmodel.connect : null,
      icon: const Icon(Icons.computer, size: 16),
      label: Text(t.keelThisPcConnect),
    );
  }
}
