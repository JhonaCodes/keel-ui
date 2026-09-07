import 'package:flutter/material.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';

/// One thing Keel AI can do, with a tappable example that fills the composer
/// (never sends it outright — the user decides whether to send it as-is or
/// edit it first).
class _AssistantCapability {
  final IconData icon;
  final String title;
  final String example;

  const _AssistantCapability({
    required this.icon,
    required this.title,
    required this.example,
  });
}

/// Shown in place of the chat's empty state on a fresh Keel AI conversation
/// — what it can register, with example prompts instead of a blank box.
class AssistantWelcomeCard extends StatelessWidget {
  const AssistantWelcomeCard({super.key, required this.onExampleTap});

  final ValueChanged<String> onExampleTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final capabilities = [
      _AssistantCapability(
        icon: Icons.forum_outlined,
        title: t.pageTitleProjects,
        example: t.assistantExampleProject,
      ),
      _AssistantCapability(
        icon: Icons.badge_outlined,
        title: t.labelAgents,
        example: t.assistantExampleAgent,
      ),
      _AssistantCapability(
        icon: Icons.account_tree_outlined,
        title: t.labelWorkflows,
        example: t.assistantExampleWorkflow,
      ),
      _AssistantCapability(
        icon: Icons.extension_outlined,
        title: t.labelSkills,
        example: t.assistantExampleSkill,
      ),
      _AssistantCapability(
        icon: Icons.rule_outlined,
        title: t.labelRules,
        example: t.assistantExampleRule,
      ),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                t.assistantWelcomeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                t.assistantWelcomeDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              for (final capability in capabilities)
                _CapabilityRow(
                  capability: capability,
                  onTap: () => onExampleTap(capability.example),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.capability, required this.onTap});

  final _AssistantCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(capability.icon, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capability.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        capability.example,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
