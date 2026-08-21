import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/queued_message.dart';

/// What the user typed while the agent was working, waiting above the
/// composer. Visible on purpose: a message that vanished into a queue with
/// no trace would read as a message that was lost.
///
/// [onSendNow] is offered only when the agent is idle — that happens after
/// the user stops a turn, where auto-sending would contradict the stop.
class QueuedMessagesStrip extends StatelessWidget {
  const QueuedMessagesStrip({
    super.key,
    required this.messages,
    required this.isStreaming,
    required this.onRemove,
    required this.onSendNow,
  });

  final List<QueuedMessage> messages;
  final bool isStreaming;
  final ValueChanged<int> onRemove;
  final VoidCallback onSendNow;

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
                Icons.schedule_send_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isStreaming
                      ? 'En cola — se envía cuando el agente termine'
                      : 'En cola — el agente está libre',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              if (!isStreaming)
                TextButton(
                  onPressed: onSendNow,
                  child: const Text('Enviar ahora'),
                ),
            ],
          ),
          for (final (index, message) in messages.indexed)
            _QueuedRow(message: message, onRemove: () => onRemove(index)),
        ],
      ),
    );
  }
}

class _QueuedRow extends StatelessWidget {
  const _QueuedRow({required this.message, required this.onRemove});

  final QueuedMessage message;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageCount = message.imagePaths.length;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message.text.isEmpty
                  ? '$imageCount ${imageCount == 1 ? 'imagen' : 'imágenes'}'
                  : message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          if (imageCount > 0 && message.text.isNotEmpty) ...[
            Icon(Icons.image_outlined, size: 14, color: scheme.outline),
            const SizedBox(width: 2),
            Text('$imageCount', style: TextStyle(color: scheme.outline)),
          ],
          IconButton(
            tooltip: 'Quitar de la cola',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
