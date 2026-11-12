import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/keel_remote/model/desktop_node_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/desktop_node_card.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/desktop_node_viewmodel.dart';

/// Opens «Conectar con un código», with [origin] as the server it starts
/// with.
Future<void> openNodePairingPanel(
  BuildContext context, {
  required String origin,
}) {
  return showFormPanel<void>(context, child: NodePairingPanel(origin: origin));
}

/// «Conectar con un código»: this PC becomes a node with the six digits the
/// Keel app shows under «Conectar otro nodo» › «Mac o PC», without signing
/// in. It closes once the node's token is kept; what went wrong stays in
/// it.
class NodePairingPanel extends StatefulWidget {
  const NodePairingPanel({super.key, required this.origin});

  /// The server the field starts with: the account's.
  final String origin;

  @override
  State<NodePairingPanel> createState() => _NodePairingPanelState();
}

class _NodePairingPanelState extends State<NodePairingPanel> {
  late final _server = TextEditingController(text: widget.origin);
  final _code = TextEditingController();

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final connected = await DesktopNodeService.instance.notifier
        .connectWithCode(origin: _server.text, code: _code.text);
    if (connected && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<DesktopNodeViewModel, DesktopNodeState>(
      viewmodel: DesktopNodeService.instance.notifier,
      build: (node, viewmodel, keep) {
        final t = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final busy = node.isBusy;
        final problem = node.problem;
        final failure = node.failure;
        return Scaffold(
          appBar: AppBar(
            title: Text(t.keelThisPcPairTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: node.canConnect ? _submit : null,
                  child: Text(t.keelThisPcPairSubmit),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                t.keelThisPcPairIntro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _server,
                enabled: !busy,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: t.keelApiServerLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(
                  labelText: t.keelThisPcPairCodeLabel,
                  hintText: '482 913',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              KeelLoadingBar(loading: busy),
              if (problem != null) DesktopNodeProblemLine(problem: problem),
              if (failure != null) KeelFailureText(failure: failure),
            ],
          ),
        );
      },
    );
  }
}
