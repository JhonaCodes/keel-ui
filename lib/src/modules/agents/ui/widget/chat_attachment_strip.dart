import 'dart:io';

import 'package:flutter/material.dart';

/// The images staged in the composer, before sending. Small squares so the
/// strip never steals height from the thread: the point here is "I attached
/// three things and this is the one I can drop", not looking at them.
class ChatAttachmentStrip extends StatelessWidget {
  const ChatAttachmentStrip({
    super.key,
    required this.paths,
    required this.onRemove,
  });

  final List<String> paths;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final path in paths)
            _StagedThumb(path: path, onRemove: () => onRemove(path)),
        ],
      ),
    );
  }
}

class _StagedThumb extends StatelessWidget {
  const _StagedThumb({required this.path, required this.onRemove});

  static const _size = 64.0;

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: scheme.surfaceContainerHighest,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.broken_image_outlined, color: scheme.outline),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              tooltip: 'Quitar imagen',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface,
                foregroundColor: scheme.onSurface,
              ),
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown over the whole chat while a drag hovers it. Ignores pointers: the
/// drop is handled by the platform layer underneath, and the hint must not
/// come between the cursor and it.
class ChatDropHint extends StatelessWidget {
  const ChatDropHint({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Container(
        color: scheme.scrim.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 32, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                'Soltá las imágenes para adjuntarlas',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'PNG, JPG, GIF, WEBP o BMP',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
