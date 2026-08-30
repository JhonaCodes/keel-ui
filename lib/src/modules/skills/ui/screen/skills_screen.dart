import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skill_form_screen.dart';
import 'package:keel_ui/src/modules/skills/ui/widget/skill_tile.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitleSkillsRegistered),
        actions: [
          IconButton(
            tooltip: t.tooltipImportPackage,
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => openBundleImportPanel(context),
          ),
          IconButton(
            tooltip: t.tooltipRegisterNew,
            icon: const Icon(Icons.add),
            onPressed: () => openSkillFormScreen(context),
          ),
        ],
      ),
      body: Column(
        children: [
          const _SuggestionsBand(),
          Expanded(
            child: ReactiveViewModelBuilder<SkillsViewModel, SkillsState>(
              viewmodel: SkillsService.instance.notifier,
              build: (state, viewmodel, keep) {
                if (state.skills.isEmpty) {
                  return Center(child: Text(t.messageNoSkillsRegistered));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.skills.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      SkillTile(skill: state.skills[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Deterministic "you keep asking for this" suggestions — creating one
/// opens the skill form prefilled as GLOBAL with the samples as a draft.
class _SuggestionsBand extends StatelessWidget {
  const _SuggestionsBand();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<
      PromptInsightsViewModel,
      PromptInsightsState
    >(
      viewmodel: PromptInsightsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final pending = state.pending;
        if (pending.isEmpty) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: scheme.secondaryContainer,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.suggestionIntro,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              for (final suggestion in pending.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${suggestion.occurrences}× · '
                          '"${suggestion.sampleTexts.first}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          viewmodel.resolveSuggestion(
                            suggestion.id,
                            dismissed: false,
                          );
                          openSkillFormScreen(
                            context,
                            draftGlobal: true,
                            draftContent:
                                '${t.suggestionDraftHeader(suggestion.occurrences)}'
                                '${suggestion.sampleTexts.map((t) => '- $t').join('\n')}\n\n'
                                '${t.suggestionDraftFooter}',
                          );
                        },
                        child: Text(t.buttonCreateSkill),
                      ),
                      IconButton(
                        tooltip: t.tooltipDismiss,
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => viewmodel.resolveSuggestion(
                          suggestion.id,
                          dismissed: true,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
