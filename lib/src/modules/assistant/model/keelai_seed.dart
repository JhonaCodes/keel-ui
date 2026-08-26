import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// El contenido del mapa y el system prompt viven centralizados en
/// `integrations/system_prompt/`, con el resto de los prompts de la app. Se
/// re-exportan acá porque este archivo era su dirección conocida: quien
/// importaba `keelai_seed.dart` los sigue viendo.
export 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart'
    show kKeelAiSkillContent, kKeelAiSystemPrompt;

/// The one skill Keel AI is always seeded with — the domain map. Lives as a
/// `Skill` so it travels through the same injection pipeline as everything
/// else, but its CONTENT is app-owned and force-synced on every launch
/// (see [seedKeelAi]): the map must always describe the app as shipped,
/// never drift as stale data. Manual edits to it are overwritten at the
/// next start.
const kKeelAiSkillName = 'keelai-mapa-del-sistema';

/// Ensures the reserved profile and its knowledge skill exist, AND keeps
/// BOTH the profile's `systemPrompt` and the map skill's content in sync
/// with the compiled constants on every launch — Keel AI's knowledge of the
/// system ships with the code, it never drifts as stale data. Safe to call
/// on every app start. Must be awaited AFTER `AgentProfilesService`/
/// `SkillsService`'s own persisted catalogs have loaded (see `ready` on
/// each ViewModel), or an empty in-flight list would look like "doesn't
/// exist yet" and create a duplicate.
Future<void> seedKeelAi() async {
  final profiles = AgentProfilesService.instance.notifier;
  final skills = SkillsService.instance.notifier;

  await Future.wait([profiles.ready, skills.ready]);

  if (!skills.data.skills.any((skill) => skill.name == kKeelAiSkillName)) {
    skills.createSkill(name: kKeelAiSkillName, content: kKeelAiSkillContent);
  } else {
    await skills.syncReservedSkillContent(
      kKeelAiSkillName,
      kKeelAiSkillContent,
    );
  }

  final existing = profiles.data.profiles
      .where((profile) => profile.name == kKeelAiHandle)
      .firstOrNull;
  if (existing == null) {
    await profiles.seedReservedProfile(
      AgentProfile(
        id: generateUuidV4(),
        name: kKeelAiHandle,
        role: 'asistente del sistema',
        systemPrompt: kKeelAiSystemPrompt,
        skills: const [kKeelAiSkillName],
        rules: const [],
        model: kDefaultClaudeModelAlias,
        effort: kDefaultEffortAlias,
        createdAt: DateTime.now(),
      ),
    );
  } else {
    await profiles.syncReservedProfilePrompt(existing.id, kKeelAiSystemPrompt);
  }
}
