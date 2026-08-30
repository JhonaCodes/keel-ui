import 'dart:io';

import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

/// The images attached to a message, as bounded PREVIEW boxes inside the
/// bubble — never at full size. A dropped screenshot is often 3000px wide;
/// rendered raw it would blow the bubble past the thread and push the text
/// out of view, so every attachment gets the same fixed card and the real
/// thing opens on tap.
class ChatImageAttachments extends StatelessWidget {
  const ChatImageAttachments({super.key, required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final path in paths) _AttachmentCard(path: path)],
      ),
    );
  }
}

/// One preview card. Fixed box, cropped to fill, tappable.
class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.path});

  static const _width = 200.0;
  static const _height = 140.0;

  final String path;

  void _openFullSize(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _FullSizeImageDialog(path: path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: t.semanticsOpenImageFullSize,
      child: Tooltip(
        message: t.tooltipOpenFullSize,
        child: InkWell(
          onTap: () => _openFullSize(context),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: _width,
              height: _height,
              color: scheme.surfaceContainerHighest,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    const _MissingAttachment(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The file behind the preview is gone (moved, or storage cleaned). Said
/// plainly instead of a broken-image glyph, because the message text stays
/// meaningful without it.
class _MissingAttachment extends StatelessWidget {
  const _MissingAttachment();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: scheme.outline),
          const SizedBox(height: 4),
          Text(
            t.messageImageUnavailable,
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

/// Read-only lightbox: the image at its real proportions, bounded to the
/// window, zoomable. Informative only — nothing to confirm here.
class _FullSizeImageDialog extends StatelessWidget {
  const _FullSizeImageDialog({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final t = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.9,
              maxHeight: size.height * 0.9,
            ),
            child: InteractiveViewer(
              maxScale: 6,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const _MissingAttachment(),
              ),
            ),
          ),
          IconButton(
            tooltip: t.buttonClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
