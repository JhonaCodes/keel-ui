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

/// Una sección del system prompt de un turno, con su prioridad de recorte.
///
/// [dropPriority] 0 nunca se recorta (identidad, reglas, contratos). Un
/// número mayor se recorta antes: el brief de saber (3) antes que una skill
/// asignada no requerida (2), y esa antes que una skill global de más (1).
class PromptSection {
  final String name;
  final String text;
  final int dropPriority;

  const PromptSection({
    required this.name,
    required this.text,
    this.dropPriority = 0,
  });
}

/// Techo del system prompt de un turno, en caracteres, cuando la policy no
/// dice otra cosa. Sesenta mil son unos quince mil tokens: alcanza para la
/// identidad, las reglas y varias skills, y deja la ventana para el trabajo.
const kDefaultSystemPromptMaxChars = 60000;

/// Lo que queda del prompt después de aplicar el techo, y qué se recortó.
class BudgetedPrompt {
  final String text;
  final List<String> dropped;
  final int totalChars;

  const BudgetedPrompt({
    required this.text,
    required this.dropped,
    required this.totalChars,
  });
}

/// Aplica el techo: mientras el total supere [maxChars], saca la sección de
/// mayor [PromptSection.dropPriority] (la última entre iguales). Las de
/// prioridad 0 nunca salen: un prompt sin reglas es peor que uno largo.
BudgetedPrompt budgetTurnSystemPrompt(
  List<PromptSection> sections, {
  required int maxChars,
}) {
  final kept = [...sections];
  final dropped = <String>[];
  final total = sections.fold<int>(0, (sum, section) => sum + section.text.length);
  var current = total;
  while (current > maxChars) {
    PromptSection? victim;
    var victimIndex = -1;
    for (var i = 0; i < kept.length; i++) {
      final section = kept[i];
      if (section.dropPriority <= 0) continue;
      if (victim == null || section.dropPriority >= victim.dropPriority) {
        victim = section;
        victimIndex = i;
      }
    }
    if (victim == null) break;
    kept.removeAt(victimIndex);
    dropped.add(victim.name);
    current -= victim.text.length;
  }
  return BudgetedPrompt(
    text: kept
        .map((section) => section.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n'),
    dropped: dropped,
    totalChars: total,
  );
}
