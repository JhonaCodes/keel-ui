import 'package:keel_ui/src/modules/skills/model/skill.dart';

/// Returns assigned, non-global skills once per name.
///
/// Global skills are composed separately at the beginning of the prompt, so
/// including them here would duplicate their content.
List<Skill> assignedNonGlobalSkills(
  Iterable<Skill> skills,
  Iterable<String> names,
) {
  final byName = <String, Skill>{};
  for (final skill in skills) {
    byName.putIfAbsent(skill.name, () => skill);
  }
  final seen = <String>{};
  return [
    for (final name in names)
      if (seen.add(name))
        if (byName[name] case final skill?
            when !skill.isGlobal && skill.content.isNotEmpty)
          skill,
  ];
}

/// Appends dynamic prompt sections after all stable sections.
///
/// [stablePrompt] contains the profile, capabilities, rules and delivery
/// contract. Knowledge and session plan change during a workflow, so they are
/// kept at the end to preserve the cacheable prefix.
String composeTurnSystemPrompt({
  required String stablePrompt,
  String knowledge = '',
  String plan = '',
}) => [stablePrompt, knowledge, plan]
    .map((section) => section.trim())
    .where((section) => section.isNotEmpty)
    .join('\n\n');
