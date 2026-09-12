part of '../system_prompt.dart';

String consultRequestPrompt({
  required String askerHandle,
  required String askerRole,
  required String excerpt,
}) =>
    '@$askerHandle ($askerRole) te pide una consulta acotada:\n\n'
    '$excerpt\n\n'
    'Responde desde tu especialidad y las skills asignadas. Incluye conclusión, '
    'evidencia con archivos o fuentes, objeciones y dudas pendientes, y una '
    'recomendación verificable para el responsable. Si falta contexto, pide '
    'el dato concreto al agente que consulta. No supongas que él tiene razón. '
    'Esta consulta es de solo lectura: no habilita escribir ni abrir trabajo '
    'de implementación paralelo. $kNeutralSpanishPrompt';

String consultAnswerPrompt({
  required String targetHandle,
  required String answer,
}) =>
    '@$targetHandle respondió tu consulta:\n\n$answer\n\n'
    'Integra la evidencia en tu decisión. Si hay contradicciones relevantes, '
    'resuélvelas mediante una consulta concreta; deja clara tu conclusión y '
    'continúa tu paso sin esperar otro mensaje del usuario.';
