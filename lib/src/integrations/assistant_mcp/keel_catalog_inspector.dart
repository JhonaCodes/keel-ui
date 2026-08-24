import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Read-only, typed view of Keel's live catalog for the system assistant.
///
/// Keel AI must reason from these domain models rather than from persisted
/// JSON shapes. Keeping the formatting pure makes the contract testable and
/// prevents its read tools from silently omitting fields used by execution.
class KeelCatalogInspector {
  final List<AgentProfile> profiles;
  final List<Workflow> workflows;
  final List<Project> projects;
  final Set<String> skillNames;
  final Set<String> ruleNames;
  final Set<String> knowledgeBaseNames;
  final Set<String> hookNames;

  const KeelCatalogInspector({
    required this.profiles,
    required this.workflows,
    required this.projects,
    required this.skillNames,
    required this.ruleNames,
    required this.knowledgeBaseNames,
    required this.hookNames,
  });

  String describeWorkflow(Workflow workflow) {
    final capabilities = workflow.capabilities.isEmpty
        ? defaultWorkflowCapabilities(
            workflow.kind,
            workflow.policy.resolutionRole,
          )
        : workflow.capabilities;
    return [
      'Workflow "${workflow.name}"',
      'ID: ${workflow.id}',
      'Intención: ${workflow.whenToApply}',
      'Tipo: ${workflow.kind.name}',
      'Responsable: ${_valueOr(workflow.policy.resolutionRole, 'auto')}',
      'Skills por turno: ${_orNone(workflow.skillNames)}',
      'Skills obligatorias: '
          '${_orNone(workflow.policy.requiredSkillNames)}',
      'Reglas obligatorias: '
          '${_orNone(workflow.policy.requiredRuleNames)}',
      'Conocimiento obligatorio: '
          '${_orNone(workflow.policy.requiredKnowledgeBaseNames)}',
      'Gates: '
          '${_orNone(workflow.policy.qualityGates.map((gate) => gate.name))}',
      'Reformulaciones máximas: ${workflow.policy.maxReplans}',
      'Subagentes máximos: ${workflow.policy.maxSubagents}',
      'Construye roadmap: ${workflow.buildsRoadmap ? 'sí' : 'no'}',
      'Capacidades (${capabilities.length}):',
      for (final capability in capabilities) ...[
        '- ${capability.id}: ${capability.title}',
        '  rol: ${capability.role} · activación: '
            '${capability.activation.name} · independiente: '
            '${capability.requiresIndependentOwner ? 'sí' : 'no'}',
        '  dependencias: ${_orNone(capability.dependencyIds)}',
        '  instrucción: ${capability.instruction}',
      ],
    ].join('\n');
  }

  /// Complete workflow inventory used by Keel AI when it must compare or
  /// redesign the catalog. Unlike the summary catalog, this never omits
  /// execution fields that would be lost by a subsequent update.
  String describeWorkflows({List<String> names = const []}) {
    final requestedNames = {
      for (final name in names.map((entry) => entry.trim()))
        if (name.isNotEmpty) name,
    };
    final selected =
        workflows
            .where(
              (workflow) =>
                  requestedNames.isEmpty ||
                  requestedNames.contains(workflow.name),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final existingNames = {for (final workflow in selected) workflow.name};
    final missingNames = requestedNames.difference(existingNames).toList()
      ..sort();

    if (selected.isEmpty && missingNames.isEmpty) {
      return 'No hay workflows registrados.';
    }

    return [
      'Workflows completos (${selected.length}):',
      for (var index = 0; index < selected.length; index++) ...[
        '',
        '--- ${index + 1}/${selected.length} ---',
        describeWorkflow(selected[index]),
      ],
      if (missingNames.isNotEmpty) ...[
        '',
        'No encontrados: ${missingNames.join(', ')}',
      ],
    ].join('\n');
  }

  String describeAgent(AgentProfile profile) => [
    'Agente @${profile.name}',
    'ID: ${profile.id}',
    'Rol: ${profile.role}',
    'Proveedor: ${profile.provider.alias}',
    'Modelo: ${profile.model}',
    'Esfuerzo: ${profile.effort}',
    'Constructor del sistema: ${profile.canManageSystem ? 'sí' : 'no'}',
    'Creado por: ${_profileName(profile.createdByProfileId)}',
    'Skills: ${_orNone(profile.skills)}',
    'Reglas: ${_orNone(profile.rules)}',
    'Tools: ${_orNone(profile.tools)}',
    'MCPs: ${_orNone(profile.mcpServers)}',
    'Hooks: ${_orNone(profile.hooks)}',
    'Conocimiento: ${_orNone(profile.knowledgeBaseNames)}',
    '',
    'System prompt:',
    profile.systemPrompt,
  ].join('\n');

  String describeProject(Project project) {
    final members = [
      for (final profileId in project.profileIds)
        if (_profileById(profileId) case final profile?)
          _memberLine(project, profile)
        else
          '@$profileId [REFERENCIA INVÁLIDA]',
    ];
    final availableWorkflows = [
      for (final workflowId in project.workflowIds)
        if (_workflowById(workflowId) case final workflow?)
          workflow.name
        else
          '$workflowId [REFERENCIA INVÁLIDA]',
    ];
    final assignments = <String>[];
    for (final workflowEntry in project.workflowNodeAssignments.entries) {
      final workflow = _workflowById(workflowEntry.key);
      final workflowLabel = workflow?.name ?? workflowEntry.key;
      for (final assignment in workflowEntry.value.entries) {
        assignments.add(
          '$workflowLabel/${assignment.key} → '
          '${_profileName(assignment.value)}',
        );
      }
    }
    final activeWorkflow = project.activeWorkflowId == null
        ? 'ninguno'
        : _workflowById(project.activeWorkflowId!)?.name ??
              '${project.activeWorkflowId} [REFERENCIA INVÁLIDA]';
    final activeSession = project.activeSessionId == null
        ? 'ninguna'
        : project.sessions
                  .where((session) => session.id == project.activeSessionId)
                  .firstOrNull
                  ?.title ??
              '${project.activeSessionId} [REFERENCIA INVÁLIDA]';
    return [
      'Proyecto "${project.name}"',
      'ID: ${project.id}',
      'Propósito: ${project.purpose}',
      'Directorio: ${project.workingDirectory}',
      'Lo mantiene el usuario: ${project.maintained ? 'sí' : 'no, solo lectura'}',
      'Miembros efectivos (${members.length}):',
      for (final member in members) '- $member',
      'Workflows disponibles: ${_orNone(availableWorkflows)}',
      'Workflow activo: $activeWorkflow',
      'Asignaciones por nodo: ${_orNone(assignments)}',
      'Reglas: ${_orNone(project.ruleNames)}',
      'Hooks: ${_orNone(project.hookNames)}',
      'Conocimiento: ${_orNone(project.knowledgeBaseNames)}',
      'Sesiones (${project.sessions.length}):',
      for (final session in project.sessions)
        '- ${session.title} · ${session.status.name} · workflow '
            '${_workflowNameOrInvalid(session.workflowId)} '
            '· caso ${session.resolutionCase?.status.name ?? 'sin iniciar'}',
      'Sesión activa: $activeSession',
    ].join('\n');
  }

  /// Complete project inventory, including every workflow reference used by
  /// projects and their sessions. This is the counterpart to
  /// [describeWorkflows] for cross-catalog audits.
  String describeProjects({List<String> names = const []}) {
    final requestedNames = {
      for (final name in names.map((entry) => entry.trim()))
        if (name.isNotEmpty) name,
    };
    final selected =
        projects
            .where(
              (project) =>
                  requestedNames.isEmpty ||
                  requestedNames.contains(project.name),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final existingNames = {for (final project in selected) project.name};
    final missingNames = requestedNames.difference(existingNames).toList()
      ..sort();

    if (selected.isEmpty && missingNames.isEmpty) {
      return 'No hay proyectos registrados.';
    }

    return [
      'Proyectos completos (${selected.length}):',
      for (var index = 0; index < selected.length; index++) ...[
        '',
        '--- ${index + 1}/${selected.length} ---',
        describeProject(selected[index]),
      ],
      if (missingNames.isNotEmpty) ...[
        '',
        'No encontrados: ${missingNames.join(', ')}',
      ],
    ].join('\n');
  }

  /// Cross-reference problems that would otherwise make Keel AI reason from
  /// a catalog that cannot be executed as described.
  List<String> get integrityIssues {
    final issues = <String>[];
    for (final workflow in workflows) {
      for (final skill in {
        ...workflow.skillNames,
        ...workflow.policy.requiredSkillNames,
      }) {
        if (!skillNames.contains(skill)) {
          issues.add('Workflow ${workflow.name}: falta la skill $skill.');
        }
      }
      for (final rule in workflow.policy.requiredRuleNames) {
        if (!ruleNames.contains(rule)) {
          issues.add('Workflow ${workflow.name}: falta la regla $rule.');
        }
      }
      for (final base in workflow.policy.requiredKnowledgeBaseNames) {
        if (!knowledgeBaseNames.contains(base)) {
          issues.add('Workflow ${workflow.name}: falta el conocimiento $base.');
        }
      }
      final validation = validateWorkflowCapabilities(workflow.capabilities);
      if (validation != null) {
        issues.add('Workflow ${workflow.name}: $validation');
      }
    }
    for (final project in projects) {
      _inspectProject(project, issues);
    }
    return issues;
  }

  void _inspectProject(Project project, List<String> issues) {
    final members = [for (final id in project.profileIds) ?_profileById(id)];
    for (final id in project.profileIds) {
      if (_profileById(id) == null) {
        issues.add('Proyecto ${project.name}: falta el agente $id.');
      }
    }
    for (final id in project.workflowIds) {
      if (_workflowById(id) == null) {
        issues.add('Proyecto ${project.name}: falta el workflow $id.');
      }
    }
    final activeWorkflowId = project.activeWorkflowId;
    if (activeWorkflowId != null && _workflowById(activeWorkflowId) == null) {
      issues.add(
        'Proyecto ${project.name}: el workflow activo $activeWorkflowId no existe.',
      );
    }
    for (final rule in project.ruleNames) {
      if (!ruleNames.contains(rule)) {
        issues.add('Proyecto ${project.name}: falta la regla $rule.');
      }
    }
    for (final hook in project.hookNames) {
      if (!hookNames.contains(hook)) {
        issues.add('Proyecto ${project.name}: falta el hook $hook.');
      }
    }
    for (final base in project.knowledgeBaseNames) {
      if (!knowledgeBaseNames.contains(base)) {
        issues.add('Proyecto ${project.name}: falta el conocimiento $base.');
      }
    }
    for (final workflowEntry in project.workflowNodeAssignments.entries) {
      final workflow = _workflowById(workflowEntry.key);
      if (workflow == null) {
        issues.add(
          'Proyecto ${project.name}: asignación para workflow inexistente '
          '${workflowEntry.key}.',
        );
      }
      for (final assignment in workflowEntry.value.entries) {
        if (workflow != null &&
            !workflow.capabilities.any((entry) => entry.id == assignment.key)) {
          issues.add(
            'Proyecto ${project.name}: el nodo ${assignment.key} no existe '
            'en ${workflow.name}.',
          );
        }
        if (_profileById(assignment.value) == null ||
            !project.profileIds.contains(assignment.value)) {
          issues.add(
            'Proyecto ${project.name}: la asignación ${assignment.key} '
            'referencia al agente ausente ${assignment.value}.',
          );
        }
      }
    }
    for (final workflowId in project.workflowIds) {
      final workflow = _workflowById(workflowId);
      if (workflow == null) continue;
      final resolutionRole = workflow.policy.resolutionRole.trim();
      final resolutionOwner = resolutionRole.isEmpty
          ? members.firstOrNull
          : memberForRole(members, resolutionRole);
      if (resolutionOwner == null) {
        issues.add(
          'Proyecto ${project.name}/${workflow.name}: no resuelve al '
          'responsable ${resolutionRole.isEmpty ? 'sin asignar' : resolutionRole}.',
        );
      }
      final owners = <String, AgentProfile>{};
      for (final capability in workflow.capabilities.where(
        (entry) => entry.activation == WorkflowCapabilityActivation.required,
      )) {
        final overrideId = project.assignedProfileId(
          workflow.id,
          capability.id,
        );
        final owner = overrideId == null
            ? memberForRole(members, capability.role)
            : members.where((entry) => entry.id == overrideId).firstOrNull;
        if (owner == null) {
          issues.add(
            'Proyecto ${project.name}/${workflow.name}: la capacidad '
            '${capability.id} no resuelve el rol ${capability.role}.',
          );
          continue;
        }
        owners[capability.id] = owner;
      }
      for (final capability in workflow.capabilities.where(
        (entry) =>
            entry.activation == WorkflowCapabilityActivation.required &&
            entry.requiresIndependentOwner,
      )) {
        final owner = owners[capability.id];
        if (owner == null) continue;
        final dependencyOwnerIds = capability.dependencyIds
            .map((id) => owners[id]?.id)
            .whereType<String>()
            .toSet();
        if (dependencyOwnerIds.contains(owner.id)) {
          issues.add(
            'Proyecto ${project.name}/${workflow.name}: ${capability.id} '
            'no tiene un agente independiente.',
          );
        }
      }
    }
  }

  String _memberLine(Project project, AgentProfile profile) {
    final effective = project.tuned(profile);
    final tuned = project.memberTuning.containsKey(profile.id)
        ? ' · override de proyecto'
        : '';
    return '@${profile.name} · ${profile.role} · '
        '${effective.provider.alias}/${effective.model}/${effective.effort}$tuned';
  }

  AgentProfile? _profileById(String id) =>
      profiles.where((profile) => profile.id == id).firstOrNull;

  Workflow? _workflowById(String id) =>
      workflows.where((workflow) => workflow.id == id).firstOrNull;

  String _workflowNameOrInvalid(String id) {
    if (id.trim().isEmpty) return 'sin asignar';
    return _workflowById(id)?.name ?? '$id [REFERENCIA INVÁLIDA]';
  }

  String _profileName(String? id) {
    if (id == null || id.isEmpty) return 'usuario/sistema';
    final profile = _profileById(id);
    return profile == null ? '@$id [REFERENCIA INVÁLIDA]' : '@${profile.name}';
  }
}

String _orNone(Iterable<String> values) {
  final list = values.where((value) => value.trim().isNotEmpty).toList();
  return list.isEmpty ? 'ninguno' : list.join(', ');
}

String _valueOr(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();
