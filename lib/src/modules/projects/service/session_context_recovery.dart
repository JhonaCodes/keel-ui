import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/service/node_context.dart';

/// Recuperación desde el estado persistido, sin deducir el pedido del repositorio
/// ni interpretar mediante palabras clave si una pregunta merece respuesta.
extension SessionContextRecovery on Session {
  String get recoverableRequest => request.trim().isNotEmpty
      ? request
      : messages
                .where(
                  (message) =>
                      message.role == .user && message.text.trim().isNotEmpty,
                )
                .firstOrNull
                ?.text ??
            '';

  WorkNode? contextNodeFor(String profileId) {
    final ownerId = liveTurn?.profileId == profileId
        ? liveTurn?.consultOfProfileId ?? profileId
        : profileId;
    final owned = resolutionCase?.nodes.where(
      (node) => node.ownerProfileId == ownerId,
    );
    return owned?.where((node) => node.status == .running).firstOrNull ??
        owned
            ?.where((node) => node.status == .pending || node.status == .paused)
            .firstOrNull ??
        owned?.lastOrNull;
  }

  String questionRecoveryContext({
    required String profileId,
    required String workingDirectory,
    required String question,
  }) {
    final originalRequest = recoverableRequest;
    final node = contextNodeFor(profileId);
    final resolution = resolutionCase;
    final userMessages = messages
        .where(
          (message) =>
              message.role == .user &&
              message.text.trim() != originalRequest.trim(),
        )
        .toList();
    final recent = userMessages.skip(
      userMessages.length > 10 ? userMessages.length - 10 : 0,
    );
    final planContext = plan
        .map((item) {
          final marker = switch ((item.discarded, item.done)) {
            (true, _) => '-',
            (_, true) => 'x',
            _ => ' ',
          };
          return '- [$marker] ${item.text} (${item.ownerRole ?? 'sin asignar'})';
        })
        .join('\n');
    return 'CONTEXTO RECUPERADO POR KEEL: esto no es una respuesta ni una autorización del usuario.\n'
        'Antes de trasladar tu pregunta, revisa el contexto disponible. No deduzcas '
        'permisos nuevos de esta recuperación: conserva tu rol y los límites de tu turno. No deduzcas '
        'la ausencia de tarea de un árbol Git limpio ni de un roadmap sin tareas tomadas. '
        'No sustituyas este pedido por otra tarea del roadmap.\n\n'
        'PEDIDO ORIGINAL:\n$originalRequest\n\n'
        'DIRECTORIO DE TRABAJO:\n$workingDirectory\n\n'
        '${node == null ? '' : 'TU ENCARGO (${node.id}, ${node.ownerRole}, ${node.status.name}):\n${node.instruction}\n\n'}'
        '${node == null || resolution == null ? '' : 'EVIDENCIA DE TUS DEPENDENCIAS:\n${renderDependencyOutputs(dependencyOutputs(resolution, node))}\n\n'}'
        '${node?.status == .done ? 'Tu nodo ya terminó. No abras otra tarea por tu cuenta; respeta el reparto del workflow.\n\n' : ''}'
        'MENSAJES RECIENTES DEL USUARIO (incluyen correcciones posteriores al pedido):\n'
        '${recent.map((message) => message.text).join('\n\n')}\n\n'
        'DECISIONES REGISTRADAS:\n'
        '${decisions.where((decision) => decision.status != .pending).map((decision) => '- ${decision.kind.name}/${decision.status.name}: ${decision.detail}\n  ${decision.answer}').join('\n')}\n\n'
        'PLAN ACTUAL:\n'
        '$planContext\n\n'
        '${resolution == null ? '' : 'AVANCE Y EVIDENCIA DEL CASO:\n${sessionDigest(resolution)}\n\n'}'
        'PREGUNTA QUE INTENTABAS HACER:\n$question\n\n'
        'Si el contexto ya responde tu duda, continúa con el encargo. '
        'Si falta una decisión real, vuelve a llamar a ask_user con la pregunta '
        'concreta y las opciones adecuadas: se mostrará al usuario. '
        'La recuperación se realiza una sola vez por agente y turno.';
  }
}
