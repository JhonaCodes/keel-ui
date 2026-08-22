import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/repository/agent_profiles_repository.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/repository/agents_repository.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/repository/rules_repository.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/repository/settings_repository.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/repository/skills_repository.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/repository/projects_repository.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/repository/workflows_repository.dart';

/// Imports the pre-`flutter_local_db` JSON files (from
/// `getApplicationSupportDirectory()`) into the database exactly once. Safe
/// to call on every launch — no-ops after the first run.
Future<void> migrateLegacyJsonIfNeeded() async {
  if (await LocalDatabase.hasMigrated()) return;

  final dir = await getApplicationSupportDirectory();

  await _migrateList<Agent>(
    file: File('${dir.path}/agents.json'),
    decode: Agent.fromJson,
    save: AgentsRepository().save,
  );
  await _migrateList<Skill>(
    file: File('${dir.path}/skills.json'),
    decode: Skill.fromJson,
    save: SkillsRepository().save,
  );
  await _migrateList<Rule>(
    file: File('${dir.path}/rules.json'),
    decode: Rule.fromJson,
    save: RulesRepository().save,
  );
  await _migrateList<AgentProfile>(
    file: File('${dir.path}/agent_profiles.json'),
    decode: AgentProfile.fromJson,
    save: AgentProfilesRepository().save,
  );
  await _migrateList<Workflow>(
    file: File('${dir.path}/workflows.json'),
    decode: Workflow.fromJson,
    save: WorkflowsRepository().save,
  );
  await _migrateList<Project>(
    // El archivo en disco se escribió cuando esto se llamaba
    // estación: su nombre es historia, no una decisión de hoy.
    file: File('${dir.path}/stations.json'),
    decode: Project.fromJson,
    save: ProjectsRepository().save,
  );
  await _migrateSettings(File('${dir.path}/settings.json'));

  await LocalDatabase.markMigrated();
}

Future<void> _migrateList<T>({
  required File file,
  required T Function(Map<String, dynamic>) decode,
  required Future<void> Function(List<T>) save,
}) async {
  if (!await file.exists()) return;

  try {
    final content = await file.readAsString();
    if (content.trim().isEmpty || content.trim() == '[]') return;

    final decoded = jsonDecode(content) as List;
    final items = decoded
        .map((entry) => decode(entry as Map<String, dynamic>))
        .toList();
    if (items.isNotEmpty) await save(items);
  } catch (error) {
    Log.e('Failed to migrate ${file.path}', error: error);
  }
}

Future<void> _migrateSettings(File file) async {
  if (!await file.exists()) return;

  try {
    final content = await file.readAsString();
    if (content.trim().isEmpty) return;

    final settings = AppSettings.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
    await SettingsRepository().save(settings);
  } catch (error) {
    Log.e('Failed to migrate ${file.path}', error: error);
  }
}
