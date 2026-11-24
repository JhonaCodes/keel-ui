import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/integrations/context_mcp/context_mcp_server.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocalDatabase.markUnavailable);
  setUpAll(() => KeelStore.instance = const FlutterLocalDbStore());

  test(
    'a Claude 1:1 chat names its non-global skills and keeps the rest inline',
    () async {
      await ContextMcpServer.start();
      final skills = SkillsService.instance.notifier;
      final rules = RulesService.instance.notifier;
      final profiles = AgentProfilesService.instance.notifier;
      await Future.wait([skills.ready, rules.ready, profiles.ready]);
      // A real skill: its frontmatter description is the one line the
      // prompt keeps; the body below it is what must stay out.
      const assignedBody = 'ASSIGNED-SKILL-BODY: review the diff line by line.';
      const globalBody = 'GLOBAL-SKILL-BODY: always answer in Spanish.';
      const ruleBody = 'RULE-BODY: never commit without approval.';
      const profilePrompt = 'PROFILE-PROMPT: verdict first.';
      skills.createSkill(
        name: 'diff-review',
        content:
            '---\ndescription: Reviews a diff.\n---\n# Diff review\n\n'
            '$assignedBody',
      );
      skills.createSkill(
        name: 'house-language',
        content: globalBody,
        isGlobal: true,
      );
      rules.createRule(name: 'no-commit', content: ruleBody);
      profiles.createProfile(
        name: 'diff-reviewer',
        role: 'reviews diffs',
        systemPrompt: profilePrompt,
        skills: const ['diff-review'],
        rules: const ['no-commit'],
        model: kDefaultClaudeModelAlias,
        effort: 'medium',
      );
      final profileId = profiles.data.profiles
          .singleWhere((profile) => profile.name == 'diff-reviewer')
          .id;
      final skillId = skills.data.skills
          .singleWhere((skill) => skill.name == 'diff-review')
          .id;
      final viewModel = AgentsViewModel();
      // Persisted agents load asynchronously and replace the list.
      await pumpEventQueue();
      viewModel.createAgent(
        'Diff reviewer',
        model: kDefaultClaudeModelAlias,
        fullFileSystemAccess: false,
        effort: 'medium',
        profileId: profileId,
      );
      final agentId = viewModel.data.agents.single.id;

      final first = await viewModel.nextTurnSpec(agentId);
      final second = await viewModel.nextTurnSpec(agentId);
      final prompt = first.additionalSystemPrompt ?? '';

      expect(prompt, isNot(contains(assignedBody)));
      expect(prompt, contains('SKILLS DISPONIBLES'));
      expect(prompt, contains('diff-review (id: skill:$skillId)'));
      expect(prompt, contains(globalBody));
      expect(prompt, contains(ruleBody));
      expect(prompt, contains(profilePrompt));
      expect(first.mcpConfig, contains(kContextMcpServerKey));
      expect(first.extraAllowedTools, containsAll(kContextMcpToolNames));
      // One URL per chat: a new one would reopen Claude's live process.
      expect(second.mcpConfig, first.mcpConfig);
      expect(second.liveSpawnKey, first.liveSpawnKey);
    },
  );

  test('update_skill sets isGlobal with `global` and keeps it without', () async {
    final skills = SkillsService.instance.notifier;
    await skills.ready;
    skills.createSkill(
      name: 'shared-glossary',
      content: 'Glossary v1.',
      isGlobal: true,
    );
    bool isGlobal() => skills.data.skills
        .singleWhere((skill) => skill.name == 'shared-glossary')
        .isGlobal;
    Future<bool> update(Map<String, Object?> arguments) async {
      final result = await dispatchKeelAiTool(
        'keel-ai',
        CallToolRequest(name: 'update_skill', arguments: arguments),
      );
      final body =
          jsonDecode((result.content.single as TextContent).text)
              as Map<String, Object?>;
      return body['ok']! as bool;
    }

    expect(
      await update({
        'name': 'shared-glossary',
        'content': 'Glossary v2.',
        'global': false,
      }),
      isTrue,
    );
    expect(isGlobal(), isFalse);

    skills.updateSkill(
      skills.data.skills
          .singleWhere((skill) => skill.name == 'shared-glossary')
          .id,
      name: 'shared-glossary',
      content: 'Glossary v2.',
      isGlobal: true,
    );
    expect(
      await update({'name': 'shared-glossary', 'content': 'Glossary v3.'}),
      isTrue,
    );
    expect(isGlobal(), isTrue);
  });
}
