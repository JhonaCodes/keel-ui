import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

class WorkflowsRepository {
  static const _prefix = 'workflow_';

  Future<List<Workflow>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    if (records.every(_usesCurrentWorkflowSchema)) {
      return records.map(Workflow.fromJson).toList();
    }

    // Export every original record before rewriting the active catalog. The
    // archive key is deliberately outside `workflow_`, so it can never be
    // selected or executed as a workflow.
    final stamp = DateTime.now().toUtc().toIso8601String();
    final archiveKey =
        'workflowArchive_${stamp.replaceAll(RegExp(r'[^0-9]'), '')}';
    await LocalDatabase.put(archiveKey, {
      'id': stamp,
      'archivedAt': stamp,
      'reason': 'migrated_to_adaptive_capabilities',
      'workflows': records,
    });
    final workflows = records.map(migrateWorkflowRecord).toList();
    await save(workflows);
    return workflows;
  }

  Future<void> save(List<Workflow> workflows) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      workflows.map((workflow) => workflow.toJson()).toList(),
    );
  }
}

bool _usesCurrentWorkflowSchema(Map<String, dynamic> record) {
  if (record.containsKey('steps') ||
      record['kind'] is! String ||
      record['policy'] is! Map) {
    return false;
  }
  final raw = record['capabilities'];
  if (raw is! List || raw.isEmpty) return false;
  if (raw.any(
    (entry) =>
        entry is! Map ||
        entry['requiresIndependentOwner'] is! bool ||
        entry['executor'] is! String,
  )) {
    return false;
  }
  try {
    final capabilities = raw
        .whereType<Map>()
        .map(
          (entry) => WorkflowCapability.fromJson(entry.cast<String, dynamic>()),
        )
        .toList();
    return capabilities.length == raw.length &&
        validateWorkflowCapabilities(capabilities) == null;
  } catch (_) {
    return false;
  }
}

/// Rewrites one persisted record into the current declarative schema. Rows
/// from an ordered catalog are retained only as capability templates: at most
/// diagnosis, implementation, and closure are required; reviews and specialist
/// checks remain visible but optional. No runtime position is carried over.
Workflow migrateWorkflowRecord(Map<String, dynamic> record) {
  final data = Map<String, dynamic>.from(record)..remove('steps');
  final kind = _inferredKind(record);
  final oldRows = (record['steps'] as List? ?? const [])
      .whereType<Map>()
      .map((entry) => entry.cast<String, dynamic>())
      .toList();
  final storedCapabilities = (record['capabilities'] as List? ?? const [])
      .whereType<Map>()
      .map((entry) => entry.cast<String, dynamic>())
      .toList();
  final existingPolicy = WorkflowPolicy.fromJson(
    (record['policy'] as Map?)?.cast<String, dynamic>(),
  );
  final firstRole = oldRows
      .map((entry) => entry['role'] as String? ?? '')
      .firstWhere((role) => role.trim().isNotEmpty, orElse: () => '');
  final ownerRole = existingPolicy.resolutionRole.trim().isEmpty
      ? firstRole
      : existingPolicy.resolutionRole;
  final policy = existingPolicy.copyWith(resolutionRole: ownerRole);

  List<WorkflowCapability> capabilities;
  if (oldRows.isNotEmpty) {
    capabilities = _capabilitiesFromRows(oldRows);
  } else if (storedCapabilities.isNotEmpty) {
    capabilities = [
      for (final raw in storedCapabilities)
        WorkflowCapability.fromJson(raw).copyWith(
          requiresIndependentOwner:
              raw['requiresIndependentOwner'] as bool? ??
              _looksIndependent(
                '${raw['id'] ?? ''} ${raw['title'] ?? ''} ${raw['role'] ?? ''}',
              ),
        ),
    ];
  } else {
    capabilities = defaultWorkflowCapabilities(kind, ownerRole);
  }
  data['kind'] = kind.name;
  data['policy'] = policy.toJson();
  data['capabilities'] = capabilities
      .map((capability) => capability.toJson())
      .toList();
  return Workflow.fromJson(data);
}

bool _looksIndependent(String text) =>
    RegExp(r'audit|test|revis|end.to.end|e2e').hasMatch(text.toLowerCase());

WorkflowKind _inferredKind(Map<String, dynamic> record) {
  final stored = record['kind'] as String?;
  if (stored != null) {
    for (final kind in WorkflowKind.values) {
      if (kind.name == stored) return kind;
    }
  }
  final text = '${record['name'] ?? ''} ${record['whenToApply'] ?? ''}'
      .toLowerCase();
  if (text.contains('migra')) return WorkflowKind.migration;
  if (text.contains('roadmap') || text.contains('tarea')) {
    return WorkflowKind.roadmap;
  }
  if (text.contains('bug') || text.contains('error')) return WorkflowKind.bug;
  return WorkflowKind.general;
}

List<WorkflowCapability> _capabilitiesFromRows(
  List<Map<String, dynamic>> rows,
) {
  final ids = <String>{};
  final normalized =
      <({String id, String title, String role, String instruction})>[];
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final baseId = (row['id'] as String? ?? '').trim().isEmpty
        ? 'capability-${index + 1}'
        : (row['id'] as String).trim();
    var id = baseId;
    var suffix = 2;
    while (!ids.add(id)) {
      id = '$baseId-$suffix';
      suffix++;
    }
    final title = (row['title'] as String? ?? '').trim();
    final role = (row['role'] as String? ?? '').trim();
    final instruction = (row['instruction'] as String? ?? '').trim();
    normalized.add((
      id: id,
      title: title.isEmpty ? 'Capacidad ${index + 1}' : title,
      role: role.isEmpty ? '*' : role,
      instruction: instruction.isEmpty
          ? 'Producir evidencia verificable para ${title.isEmpty ? id : title}.'
          : instruction,
    ));
  }

  bool matches(int index, RegExp expression) {
    final row = normalized[index];
    return expression.hasMatch('${row.title} ${row.role}'.toLowerCase());
  }

  final diagnosis = 0;
  final implementation = List.generate(normalized.length, (index) => index)
      .where(
        (index) => matches(
          index,
          RegExp(r'implement|desarroll|flutter|coder|constructor'),
        ),
      )
      .firstOrNull;
  final closure = List.generate(normalized.length, (index) => index)
      .where(
        (index) => matches(
          index,
          RegExp(r'verificaci[oó]n|verificador|cierre|end.to.end|e2e'),
        ),
      )
      .lastOrNull;
  final required = <int>{diagnosis, ?implementation, ?closure};
  final implementationId = implementation == null
      ? normalized[diagnosis].id
      : normalized[implementation].id;

  return [
    for (var index = 0; index < normalized.length; index++)
      WorkflowCapability(
        id: normalized[index].id,
        title: normalized[index].title,
        role: normalized[index].role,
        instruction: normalized[index].instruction,
        dependencyIds: index == diagnosis
            ? const []
            : index == implementation
            ? [normalized[diagnosis].id]
            : matches(
                index,
                RegExp(r'audit|test|revis|verific|cierre|end.to.end|e2e'),
              )
            ? [implementationId]
            : [normalized[diagnosis].id],
        activation: required.contains(index)
            ? WorkflowCapabilityActivation.required
            : WorkflowCapabilityActivation.optional,
        requiresIndependentOwner: matches(
          index,
          RegExp(r'audit|test|revis|end.to.end|e2e'),
        ),
      ),
  ];
}
