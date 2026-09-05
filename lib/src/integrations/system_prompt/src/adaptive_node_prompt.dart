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

  /// Lo que dejaron las dependencias cerradas, ya rendido (ver
  /// `renderDependencyOutputs`). Vacío si ninguna cerró con bloque.
  String dependencyContext = '',

  /// El estado del caso nodo por nodo (ver `sessionDigest`). Va cuando el
  /// nodo arranca sin la sesión del CLI: es su única memoria del caso.
  String digest = '',
}) {
  final findings = resolution.findings
      .map(
        (finding) =>
            '- ${finding.evidence.source.name}: '
            '${finding.evidence.summary}',
      )
      .join('\n');
  return 'Pedido original:\n$request\n\n'
      'Sos el agente asignado al nodo "${node.title.isEmpty ? node.id : node.title}" '
      'del workflow "${workflow.name}". Contrato del nodo: '
      '${node.instruction.isEmpty ? 'producir evidencia verificable para esta capacidad' : node.instruction}. '
      'El responsable de integración conserva el rol ${resolution.ownerRole}. '
      '${dependencyContext.trim().isEmpty ? '' : '\n\nLO QUE DEJARON LOS NODOS DE LOS QUE DEPENDÉS (arrancá de acá, no lo rehagas):\n${dependencyContext.trim()}\n\n'}'
      '${digest.trim().isEmpty ? '' : '\n\nESTADO DEL CASO HASTA ACÁ:\n${digest.trim()}\n\n'}'
      'No recorras un flujo fijo ni delegues '
      'la escritura. Trabajá solo lo que desbloquea este nodo y conservá la '
      'evidencia verificable. Hallazgos abiertos:\n'
      '${findings.isEmpty ? '- ninguno' : findings}\n\n'
      'Antes de cerrar, ejecutá el gate que corresponda y terminá con el '
      'bloque ```keel-outcome (status, summary con la evidencia, files, '
      'artifacts${isAudit ? ', y verdict GO o NO-GO: en este nodo el veredicto es obligatorio y NO-GO exige el hallazgo con su ubicación' : ''}). '
      'Si este es una migración, registrá cada área que verificaste con '
      'bloques ```cobertura (area: model|serialization|persistence|'
      'dataMigration|callers|compatibility|tests|ui; estado: '
      'satisfied|notApplicable; motivo: evidencia o justificación).';
}
