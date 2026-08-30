import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

Future<void> openSessionAgentPicker(
  BuildContext context, {
  required String projectId,
  required String sessionId,
}) {
  return showFormPanel<void>(
    context,
    child: SessionAgentPicker(projectId: projectId, sessionId: sessionId),
  );
}

/// Adds/removes agents for ONE session. The project's standing roster is
/// read-only here — changing it for every session is the project form's job.
class SessionAgentPicker extends StatelessWidget {
  const SessionAgentPicker({
    super.key,
    required this.projectId,
    required this.sessionId,
  });

  final String projectId;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.labelSessionAgents)),
      body: ReactiveViewModelBuilder<ProjectsViewModel, ProjectsState>(
        viewmodel: ProjectsService.instance.notifier,
        build: (state, projectsViewModel, keep) {
          final project = state.projects
              .where((entry) => entry.id == projectId)
              .firstOrNull;
          final session = project?.sessions
              .where((entry) => entry.id == sessionId)
              .firstOrNull;
          if (project == null || session == null) {
            return Center(child: Text(t.messageSessionGone));
          }
          return _PickerBody(project: project, session: session);
        },
      ),
    );
  }
}

class _PickerBody extends StatelessWidget {
  const _PickerBody({required this.project, required this.session});

  final Project project;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (profilesState, profilesViewModel, keep) {
        final projects = ProjectsService.instance.notifier;
        final standing = profilesState.profiles
            .where((profile) => project.profileIds.contains(profile.id))
            .toList();
        final extras = profilesState.profiles
            .where((profile) => session.extraProfileIds.contains(profile.id))
            .toList();
        final available = profilesState.profiles
            .where(
              (profile) =>
                  profile.name != kKeelAiHandle &&
                  !project.profileIds.contains(profile.id) &&
                  !session.extraProfileIds.contains(profile.id),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionLabel(t.sectionProjectMembers),
            for (final profile in standing)
              ListTile(
                dense: true,
                leading: const Icon(Icons.badge_outlined, size: 18),
                title: Text(profile.name),
                subtitle: profile.role.isEmpty ? null : Text(profile.role),
              ),
            const Divider(height: 16),
            _SectionLabel(t.sectionSessionOnly),
            if (extras.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(t.messageNoExtraAgentsYet),
              ),
            for (final profile in extras)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_add_alt_outlined, size: 18),
                title: Text(profile.name),
                subtitle: profile.role.isEmpty ? null : Text(profile.role),
                trailing: IconButton(
                  tooltip: t.tooltipRemoveFromSession,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () => projects.removeAgentFromSession(
                    project.id,
                    session.id,
                    profile.id,
                  ),
                ),
              ),
            const Divider(height: 16),
            _SectionLabel(t.sectionAddToSession),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(t.messageNoAgentsToAdd),
              ),
            for (final profile in available)
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 18),
                title: Text(profile.name),
                subtitle: profile.role.isEmpty ? null : Text(profile.role),
                onTap: () => projects.addAgentToSession(
                  project.id,
                  session.id,
                  profile.id,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
