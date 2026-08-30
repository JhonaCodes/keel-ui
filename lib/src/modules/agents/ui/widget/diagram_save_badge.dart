import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

/// Pins a small "save as PNG" action to the corner of [child], so it always
/// stays attached to the diagram itself regardless of how wide it renders —
/// instead of floating off to the side of a much wider container.
class DiagramSaveBadge extends StatelessWidget {
  const DiagramSaveBadge({
    super.key,
    required this.child,
    required this.onSave,
  });

  final Widget child;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Stack(
      children: [
        child,
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              tooltip: t.actionSaveAsPng,
              icon: Icon(
                Icons.download_outlined,
                size: 16,
                color: scheme.onPrimary,
              ),
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              onPressed: onSave,
            ),
          ),
        ),
      ],
    );
  }
}
