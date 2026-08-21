import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/shared/shared.dart';

const _stationKeys = {
  'nombre',
  'proposito',
  'carpeta',
  'agentes',
  'workflows',
  'reglas',
};
const _agentKeys = {
  'handle',
  'rol',
  'proposito',
  'instrucciones',
  'skills',
  'reglas',
  'tools',
  'mcps',
};
const _workflowKeys = {'nombre', 'cuando', 'pasos'};
const _skillKeys = {'nombre', 'contenido', 'global'};
const _ruleKeys = {'nombre', 'contenido'};

/// Reads every action block Keel AI wrote in [text] and returns them ready to
/// execute, in a fixed dependency order — skills and rules first, then
/// agents (which may reference them by name), then workflows, then stations
/// (which may reference agents and workflows by name and need their real
/// ids to already exist). This is NOT the order the blocks appeared in the
/// reply: a station block written before the agent block that creates one of
/// its members must still resolve that member correctly.
List<AssistantAction> parseAssistantActions(String text) {
  final actions = <AssistantAction>[];

  for (final fields in parseFencedBlocks(
    text,
    tag: 'skill',
    keys: _skillKeys,
  )) {
    final name = fields['nombre'];
    if (name == null || name.isEmpty) continue;
    actions.add(
      CreateSkillAction(
        name: name,
        content: fields['contenido'] ?? '',
        isGlobal: _parseBool(fields['global']),
      ),
    );
  }

  for (final fields in parseFencedBlocks(text, tag: 'regla', keys: _ruleKeys)) {
    final name = fields['nombre'];
    if (name == null || name.isEmpty) continue;
    actions.add(
      CreateRuleAction(name: name, content: fields['contenido'] ?? ''),
    );
  }

  for (final fields in parseFencedBlocks(
    text,
    tag: 'agente',
    keys: _agentKeys,
  )) {
    final handle = fields['handle'];
    if (handle == null || handle.isEmpty) continue;
    actions.add(
      CreateAgentAction(
        handle: handle,
        role: fields['rol'],
        purpose: fields['proposito'],
        instructions: fields['instrucciones'],
        skillNames: _splitList(fields['skills']),
        ruleNames: _splitList(fields['reglas']),
        // Assignment only — there is deliberately no fenced-block form for
        // CREATING a tool (see CreateToolAction): this parser collapses
        // blank lines and indentation, which would corrupt script code.
        toolNames: _splitList(fields['tools']),
        mcpServerNames: _splitList(fields['mcps']),
      ),
    );
  }

  for (final fields in parseFencedBlocks(
    text,
    tag: 'workflow',
    keys: _workflowKeys,
  )) {
    final name = fields['nombre'];
    if (name == null || name.isEmpty) continue;
    actions.add(
      CreateWorkflowAction(
        name: name,
        whenToApply: fields['cuando'] ?? '',
        steps: _parseSteps(fields['pasos'] ?? ''),
      ),
    );
  }

  for (final fields in parseFencedBlocks(
    text,
    tag: 'estacion',
    keys: _stationKeys,
  )) {
    final name = fields['nombre'];
    if (name == null || name.isEmpty) continue;
    actions.add(
      CreateStationAction(
        name: name,
        purpose: fields['proposito'] ?? '',
        workingDirectory: fields['carpeta'] ?? '',
        agentHandles: _splitList(fields['agentes']),
        workflowNames: _splitList(fields['workflows']),
        ruleNames: _splitList(fields['reglas']),
      ),
    );
  }

  return actions;
}

bool _parseBool(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  return normalized == 'si' || normalized == 'sí' || normalized == 'true';
}

List<String> _splitList(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

/// Each `pasos:` line is `título | rol | instrucción` — the one place a
/// generic block field gets structure, kept local to the action it belongs
/// to instead of teaching the shared parser about repeated keys.
List<WorkflowStep> _parseSteps(String raw) {
  final steps = <WorkflowStep>[];
  for (final line in raw.split('\n')) {
    final parts = line.split('|');
    if (parts.length < 3) continue;
    final title = parts[0].trim();
    if (title.isEmpty) continue;
    steps.add(
      WorkflowStep(
        id: generateUuidV4(),
        title: title,
        role: parts[1].trim(),
        // Rejoin any extra `|` untrimmed, then trim once — trimming each
        // part first and rejoining with a bare `|` would eat the spacing
        // around a literal `|` inside the instruction text.
        instruction: parts.sublist(2).join('|').trim(),
      ),
    );
  }
  return steps;
}
