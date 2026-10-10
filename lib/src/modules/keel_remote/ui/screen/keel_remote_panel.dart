import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_account_tab.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_nodes_tab.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_sessions_tab.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_tasks_tab.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_account_viewmodel.dart';

/// Opens the Keel API panel from the rail, as every record of the rail
/// opens: a panel on the right that closes, with the conversation behind it.
Future<void> openKeelRemotePanel(BuildContext context) {
  return showFormPanel<void>(
    context,
    width: 720,
    child: const KeelRemotePanel(),
  );
}

/// «Cuenta», «Nodos», «Tareas» and «Sesiones» of the person's own Keel API.
/// Following a task or talking to a server's Keel AI happens in the central
/// area: the rows here open it and close the panel.
class KeelRemotePanel extends StatelessWidget {
  const KeelRemotePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<KeelAccountViewModel, KeelAccountState>(
      viewmodel: KeelAccountService.instance.notifier,
      build: (account, viewmodel, keep) => DefaultTabController(
        length: 4,
        // Signed in, the queue is what one comes for; signed out, the
        // sign-in form.
        initialIndex: account.isSignedIn ? 2 : 0,
        child: Scaffold(
          appBar: AppBar(
            title: Text(t.keelApiPanelTitle),
            bottom: TabBar(
              tabs: [
                Tab(text: t.keelApiTabAccount),
                Tab(text: t.keelApiTabNodes),
                Tab(text: t.keelApiTabTasks),
                Tab(text: t.keelApiTabSessions),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const KeelAccountTab(),
              if (account.isSignedIn) ...const [
                KeelNodesTab(),
                KeelTasksTab(),
                KeelSessionsTab(),
              ] else ...const [
                KeelSignInFirst(),
                KeelSignInFirst(),
                KeelSignInFirst(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
