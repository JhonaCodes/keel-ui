part of '../system_prompt.dart';

/// EL CONTRATO DE UN NODO de un workflow adaptativo.
///
/// Qué dice: el pedido original del usuario, qué nodo le tocó a este agente
/// y con qué contrato, quién conserva la integración, los hallazgos todavía
/// abiertos, y qué tiene que dejar antes de cerrar — incluidos los bloques
/// ```cobertura cuando el trabajo es una migración.
///
/// Por qué existe: un workflow adaptativo no es una cinta de pasos fijos.
/// El agente necesita saber exactamente qué desbloquea SU nodo y qué
/// evidencia se le va a pedir; sin eso, o recorre un flujo que nadie le
/// pidió o cierra sin dejar con qué verificarlo.
///
/// Este es el `instruction` del turno —lo que llega como pedido—, no una
/// sección del system prompt: por eso lleva el pedido original adentro.
///
/// Quién lo usa: `_runWorkflow` en
/// `modules/projects/viewmodel/projects_viewmodel.dart`.
///

String adaptiveNodePrompt({
  required String request,
  required Workflow workflow,
  required ResolutionCase resolution,
  required WorkNode node,
  bool isAudit = false,
  List<AgentProfile> members = const [],

  /// Lo que dejaron las dependencias cerradas, ya rendido (ver
  /// `renderDependencyOutputs`). Vacío si ninguna cerró con bloque.
  String dependencyContext = '',

  /// El estado del caso nodo por nodo (ver `sessionDigest`). Va cuando el
  /// nodo arranca sin la sesión del CLI: es su única memoria del caso.
  String digest = '',
}) {
  final assignments = resolution.nodes
      .map((entry) {
        final owner = members
            .where((profile) => profile.id == entry.ownerProfileId)
            .firstOrNull;
        final capability = workflow.capabilities
            .where((item) => item.id == entry.id)
            .firstOrNull;
        final outputContract = capability?.outputContract ?? '';
        return '- ${entry.title.isEmpty ? entry.id : entry.title}: '
            '${owner == null ? entry.ownerRole : '@${owner.name} (${owner.role})'}; '
            'depende de: ${entry.dependencyIds.isEmpty ? 'ningún nodo' : entry.dependencyIds.join(', ')}; '
            'encargo: ${entry.instruction}; '
            'salida: ${outputContract.isEmpty ? 'evidencia verificable y estado del trabajo' : outputContract}'
            '${owner == null || owner.skills.isEmpty ? '' : '; skills: ${owner.skills.join(', ')}'}';
      })
      .join('\n');
  final findings = resolution.findings
      .map(
        (finding) =>
            '- ${finding.evidence.source.name}: '
            '${finding.evidence.summary}',
      )
      .join('\n');
  return 'Pedido original:\n$request\n\n'
      'REPARTO DEL TRABAJO ENTRE AGENTES:\n$assignments\n\n'
      'Eres el agente asignado al nodo "${node.title.isEmpty ? node.id : node.title}" '
      'del workflow "${workflow.name}". Contrato del nodo: '
      '${node.instruction.isEmpty ? 'producir evidencia verificable para esta capacidad' : node.instruction}. '
      'El responsable de integración conserva el rol ${resolution.ownerRole}. '
      'Tu responsabilidad es ${node.ownerRole}. Antes de cerrar deja para el '
      'siguiente responsable: cambios, archivos, verificaciones y resultados, '
      'decisiones de expertos y pendientes concretos. Si falta evidencia de '
      'una especialidad necesaria, consulta al experto antes de decidir. '
      '$kPlanningDiagramPrompt '
      'Toma la iniciativa dentro de tu contrato: al recibir el plan, ejecuta '
      'la implementación si ese es tu rol; no esperes otro mensaje humano '
      'para empezar. Consulta a tus compañeros por su especialidad y '
      'retoma tu trabajo con sus respuestas. '
      '${dependencyContext.trim().isEmpty ? '' : '\n\nLO QUE DEJARON LOS NODOS DE LOS QUE DEPENDES (parte de esta evidencia):\n${dependencyContext.trim()}\n\n'}'
      '${digest.trim().isEmpty ? '' : '\n\nESTADO ACTUAL DEL CASO:\n${digest.trim()}\n\n'}'
      '${node.output?.status == TurnOutcomeStatus.inProgress ? '\n\nAVANCE DE TU TURNO ANTERIOR (continúa desde aquí):\n${node.output?.summary}\n${node.output?.artifacts}\n\n' : ''}'
      'No recorras un flujo fijo ni delegues '
      'la escritura. Trabaja solo en lo que desbloquea este nodo y conserva la '
      'evidencia verificable. Hallazgos abiertos:\n'
      '${findings.isEmpty ? '- ninguno' : findings}\n\n'
      'Antes de cerrar, ejecuta el gate que corresponda y termina con el '
      'bloque ```keel-outcome (status, summary con la evidencia, files, '
      'artifacts${isAudit ? ', y verdict GO o NO-GO: en este nodo el veredicto es obligatorio y NO-GO exige el hallazgo con su ubicación' : ''}). '
      'Si este es una migración, registra cada área que verificaste con '
      'bloques ```cobertura (area: model|serialization|persistence|'
      'dataMigration|callers|compatibility|tests|ui; estado: '
      'satisfied|notApplicable; motivo: evidencia o justificación).';
}
