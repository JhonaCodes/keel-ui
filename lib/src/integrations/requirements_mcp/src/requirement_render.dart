part of '../requirements_mcp.dart';

/// **La frontera entre dos proyectos, hecha función.**
///
/// Todo lo que cruza de un proyecto a otro pasa por acá. Si algo del contexto
/// de origen se cuela en este render, la frontera se cae en silencio y nadie
/// se entera: no hay error, solo dos proyectos que empiezan a saber cosas del
/// otro. Es la función a mirar en cualquier cambio futuro.
///
/// Lo que entra: la necesidad, el contexto que escribió quien pidió, el
/// veredicto y el hilo compartido. Lo que NO entra, y no es por olvido: el
/// hilo de la sesión de origen, su plan, su carpeta, su `TASKS/`, sus reglas
/// y sus bases de saber.
Map<String, dynamic> renderRequirement(
  InternalRequirement requirement, {
  required String fromProject,
  required String toProject,
}) => {
  'codigo': requirement.code,
  'titulo': requirement.title,
  'lo_pide': fromProject,
  'se_lo_pide_a': toProject,
  'necesita': requirement.need,
  if (requirement.context.isNotEmpty) 'contexto': requirement.context,
  'bloquea_a_quien_pide': requirement.blocking,
  'estado': requirement.status.alias,
  'lo_abrio': requirement.openedByHandle,
  if (requirement.takenByHandle != null) 'lo_tomo': requirement.takenByHandle,
  if (requirement.verdict != null)
    'veredicto': {
      'que_dijo': requirement.verdict!.kind.alias,
      'razon': requirement.verdict!.reason,
      if (requirement.verdict!.prerequisites.isNotEmpty)
        'antes_hay_que': requirement.verdict!.prerequisites,
    },
  if (requirement.thread.isNotEmpty)
    'hilo': [
      for (final entry in requirement.thread)
        {
          'lado': entry.side.alias,
          'quien': entry.authorHandle ?? 'el usuario',
          'que': entry.text,
        },
    ],
};

/// Para qué se le manda el requerimiento a un turno.
///
/// El bloque es el mismo —la frontera no cambia— pero lo que se le pide al
/// final no: a quien va a trabajar se le pide un veredicto, y a quien está
/// contestando una pregunta en el hilo, no. Mandarle «dejá el veredicto con
/// record_verdict» a un turno que ni siquiera tiene esa tool es pedirle algo
/// imposible y después leer una disculpa.
enum RequirementTurnPurpose {
  /// Va a evaluarlo contra su roadmap y decidir.
  evaluar,

  /// Le preguntaron algo en el hilo y contesta.
  consultar,
}

/// El requerimiento tal como entra al PEDIDO de un turno.
///
/// Va como texto y no como estado compartido: el turno del destino no abre la
/// sesión del origen ni hereda nada suyo, recibe este bloque y trabaja.
String renderRequirementForTurn(
  InternalRequirement requirement, {
  required String fromProject,
  required String toProject,
  RequirementTurnPurpose purpose = RequirementTurnPurpose.evaluar,
}) {
  final buffer = StringBuffer()
    ..writeln('REQUERIMIENTO ${requirement.code} — ${requirement.title}')
    ..writeln('Lo pide el proyecto "$fromProject". Vos sos "$toProject".')
    ..writeln()
    ..writeln('NECESITA: ${requirement.need}');
  if (requirement.context.isNotEmpty) {
    buffer.writeln('CONTEXTO DE QUIEN PIDE: ${requirement.context}');
  }
  if (requirement.blocking) {
    buffer.writeln('Está frenado esperando esto.');
  }
  for (final entry in requirement.thread) {
    buffer.writeln(
      '- [${entry.side.label}] ${entry.authorHandle ?? 'el usuario'}: '
      '${entry.text}',
    );
  }
  buffer.writeln();
  if (purpose == RequirementTurnPurpose.consultar) {
    buffer.writeln(
      'Esto es el estado del requerimiento y su hilo, para que contestes con '
      'el contexto completo. No es un pedido de trabajo: no evalúes contra tu '
      'roadmap ni dictamines nada todavía.',
    );
    return buffer.toString();
  }
  buffer
    ..writeln(
      'ANTES DE TRABAJAR, evaluá contra TU propio roadmap y dejá el veredicto '
      'con record_verdict: viable, bloqueado (nombrando qué va primero), no '
      'viable, o ya-resuelto si esto ya existe de otra forma. No contestes en '
      'el hilo del que pidió: no lo tenés y no lo vas a tener.',
    )
    ..writeln(
      'Si el veredicto es viable, convertilo con convert_to_task: elegí en '
      'qué grupo de TU roadmap va y con qué prioridad, y queda anotado como '
      'trabajo real. Un requerimiento aceptado que no se convierte es un sí '
      'que nadie va a poder tomar después.',
    );
  return buffer.toString();
}
