import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/shared/shared.dart';

const _projectKeys = {
  'nombre',
  'proposito',
  'carpeta',
  'agentes',
  'workflows',
  'reglas',
  'hooks',
  'saber',
  'mantenido',
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
  'hooks',
  'conocimiento',
  'proveedor',
  'modelo',
  'esfuerzo',
  'constructor',
};
const _workflowKeys = {
  'nombre',
  'cuando',
  'tipo',
  'responsable',
  'skills',
  'reglas',
  'conocimiento',
  'gates',
  'max_reformulaciones',
  'max_subagentes',
  'construye_roadmap',
  'capacidades',
};
const _skillKeys = {'nombre', 'contenido', 'global'};
const _ruleKeys = {'nombre', 'contenido'};

/// Reads every action block Keel AI wrote in [text] and returns them ready to
/// execute, in a fixed dependency order — skills and rules first, then
/// agents (which may reference them by name), then workflows, then projects
/// (which may reference agents and workflows by name and need their real
/// ids to already exist). This is NOT the order the blocks appeared in the
/// reply: a project block written before the agent block that creates one of
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
        hookNames: _splitList(fields['hooks']),
        knowledgeBaseNames: _splitList(fields['conocimiento']),
        providerAlias: fields['proveedor'],
        model: fields['modelo'],
        effort: fields['esfuerzo'],
        systemBuilder: fields.containsKey('constructor')
            ? _parseBool(fields['constructor'])
            : null,
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
        kind: _workflowKind(fields['tipo']),
        resolutionRole: fields['responsable'] ?? '',
        skillNames: _splitList(fields['skills']),
        requiredRuleNames: _splitList(fields['reglas']),
        requiredKnowledgeBaseNames: _splitList(fields['conocimiento']),
        qualityGates: _workflowQualityGates(fields['gates']),
        maxReplans: _boundedInt(fields['max_reformulaciones']),
        maxSubagents: _boundedInt(fields['max_subagentes']),
        capabilities: _workflowCapabilities(fields['capacidades']),
        buildsRoadmap: fields.containsKey('construye_roadmap')
            ? _parseBool(fields['construye_roadmap'])
            : null,
      ),
    );
  }

  // `estacion` se sigue aceptando a propósito: un turno de codex arrastra el
  // system prompt del primer mensaje de su sesión, así que puede escribir el
  // nombre viejo un buen rato después de que acá se llame proyecto. Es de
  // ENTRADA solamente — lo que se le enseña a escribir es `proyecto`.
  for (final tag in const ['proyecto', 'estacion']) {
    for (final fields in parseFencedBlocks(
      text,
      tag: tag,
      keys: _projectKeys,
    )) {
      final name = fields['nombre'];
      if (name == null || name.isEmpty) continue;
      actions.add(
        CreateProjectAction(
          name: name,
          purpose: fields['proposito'] ?? '',
          workingDirectory: fields['carpeta'] ?? '',
          agentHandles: _splitList(fields['agentes']),
          workflowNames: _splitList(fields['workflows']),
          ruleNames: _splitList(fields['reglas']),
          hookNames: _splitList(fields['hooks']),
          knowledgeBaseNames: _splitList(fields['saber']),
          maintained: fields.containsKey('mantenido')
              ? _parseBool(fields['mantenido'])
              : true,
        ),
      );
    }
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

WorkflowKind _workflowKind(String? raw) => WorkflowKind.values.firstWhere(
  (kind) => kind.name == raw?.trim().toLowerCase(),
  orElse: () => WorkflowKind.general,
);

List<WorkflowQualityGate> _workflowQualityGates(String? raw) => [
  for (final name in _splitList(raw))
    for (final gate in WorkflowQualityGate.values)
      if (gate.name == name) gate,
];

/// Compact fenced-block representation:
/// id|title|role|required/optional|dep-a+dep-b|shared/independent|instruction
List<WorkflowCapability> _workflowCapabilities(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final capabilities = <WorkflowCapability>[];
  for (final encoded in raw.split(';;')) {
    final fields = encoded.split('|').map((value) => value.trim()).toList();
    if (fields.length < 7 ||
        fields[0].isEmpty ||
        (fields[5] != 'shared' && fields[5] != 'independent')) {
      continue;
    }
    capabilities.add(
      WorkflowCapability(
        id: fields[0],
        title: fields[1],
        role: fields[2].isEmpty ? '*' : fields[2],
        activation: fields[3] == 'optional'
            ? WorkflowCapabilityActivation.optional
            : WorkflowCapabilityActivation.required,
        dependencyIds: fields[4]
            .split('+')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        requiresIndependentOwner: fields[5] == 'independent',
        instruction: fields.sublist(6).join('|'),
      ),
    );
  }
  return capabilities;
}

int? _boundedInt(String? raw) {
  final value = int.tryParse(raw?.trim() ?? '');
  return value?.clamp(0, 2).toInt();
}
