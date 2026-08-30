import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/widget/agent_profile_tile.dart';

class AgentProfilesScreen extends StatelessWidget {
  const AgentProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitleAgentsRegistered),
        actions: [
          IconButton(
            tooltip: t.tooltipImportPackage,
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => openBundleImportPanel(context),
          ),
          IconButton(
            tooltip: t.tooltipRegisterNew,
            icon: const Icon(Icons.add),
            onPressed: () => openAgentProfileFormScreen(context),
          ),
        ],
      ),
      body:
          ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
            viewmodel: AgentProfilesService.instance.notifier,
            build: (state, viewmodel, keep) {
              // Keel AI's own profile never shows here: its systemPrompt is
              // app-owned mechanism re-synced on every launch (see
              // `seedKeelAi`), so an edit made through this screen's form
              // would silently revert on the next start with no indication
              // why.
              final profiles = state.profiles
                  .where((profile) => profile.name != kKeelAiHandle)
                  .toList();
              if (profiles.isEmpty) {
                return Center(child: Text(t.messageNoAgentsRegistered));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: profiles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    AgentProfileTile(profile: profiles[index]),
              );
            },
          ),
    );
  }
}
