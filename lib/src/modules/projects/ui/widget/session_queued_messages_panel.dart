import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/session_queued_message.dart';

/// Mensajes que el usuario dejó preparados mientras el workflow trabaja.
///
/// Permanecen visibles y bajo control explícito: se pueden editar, borrar,
/// mandar al terminar o usar para interrumpir el turno actual.
class SessionQueuedMessagesPanel extends StatelessWidget {
  const SessionQueuedMessagesPanel({
    super.key,
    required this.messages,
    required this.isRunning,
    required this.onEdit,
    required this.onDelete,
    required this.onSendNow,
    required this.onSendAfterTurn,
    required this.onHold,
  });

  final List<SessionQueuedMessage> messages;
  final bool isRunning;
  final ValueChanged<SessionQueuedMessage> onEdit;
  final ValueChanged<SessionQueuedMessage> onDelete;
  final ValueChanged<SessionQueuedMessage> onSendNow;
  final ValueChanged<SessionQueuedMessage> onSendAfterTurn;
  final ValueChanged<SessionQueuedMessage> onHold;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions_outlined,
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Mensajes en espera · ${messages.length}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 176),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final message = messages[index];
                return _QueuedSessionMessageRow(
                  key: ValueKey(message.id),
                  message: message,
                  isRunning: isRunning,
                  onEdit: () => onEdit(message),
                  onDelete: () => onDelete(message),
                  onSendNow: () => onSendNow(message),
                  onSendAfterTurn: () => onSendAfterTurn(message),
                  onHold: () => onHold(message),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedSessionMessageRow extends StatelessWidget {
  const _QueuedSessionMessageRow({
    super.key,
    required this.message,
    required this.isRunning,
    required this.onEdit,
    required this.onDelete,
    required this.onSendNow,
    required this.onSendAfterTurn,
    required this.onHold,
  });

  final SessionQueuedMessage message;
  final bool isRunning;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSendNow;
  final VoidCallback onSendAfterTurn;
  final VoidCallback onHold;

  String get _stateLabel => switch (message.delivery) {
    SessionQueuedDelivery.standby => 'En espera',
    SessionQueuedDelivery.afterCurrentTurn => 'Se enviará al terminar',
    SessionQueuedDelivery.interrupting => 'Interrumpiendo…',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageCount = message.imagePaths.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text.isEmpty
                        ? '$imageCount ${imageCount == 1 ? 'imagen' : 'imágenes'}'
                        : message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _stateLabel,
                        style: TextStyle(
                          color:
                              message.delivery == SessionQueuedDelivery.standby
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                          fontSize: 11,
                        ),
                      ),
                      if (imageCount > 0 && message.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.image_outlined,
                          size: 13,
                          color: scheme.outline,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$imageCount',
                          style: TextStyle(color: scheme.outline, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar mensaje en espera',
              visualDensity: VisualDensity.compact,
              iconSize: 17,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            if (message.delivery != SessionQueuedDelivery.interrupting)
              IconButton(
                tooltip: 'Enviar ahora',
                visualDensity: VisualDensity.compact,
                iconSize: 17,
                onPressed: onSendNow,
                icon: const Icon(Icons.send_outlined),
              ),
            if (isRunning &&
                message.delivery != SessionQueuedDelivery.afterCurrentTurn &&
                message.delivery != SessionQueuedDelivery.interrupting)
              IconButton(
                tooltip: 'Enviar al terminar',
                visualDensity: VisualDensity.compact,
                iconSize: 17,
                onPressed: onSendAfterTurn,
                icon: const Icon(Icons.next_plan_outlined),
              ),
            if (message.delivery != SessionQueuedDelivery.standby)
              IconButton(
                tooltip: 'Mantener en espera',
                visualDensity: VisualDensity.compact,
                iconSize: 17,
                onPressed: onHold,
                icon: const Icon(Icons.pause_outlined),
              ),
            IconButton(
              tooltip: 'Eliminar mensaje en espera',
              visualDensity: VisualDensity.compact,
              iconSize: 17,
              onPressed: onDelete,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
