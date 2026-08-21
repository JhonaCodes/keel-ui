import 'package:flutter/material.dart';

/// Opens [child] as a full-height panel that slides in from the right, over a
/// scrim — the desktop equivalent of an end drawer.
///
/// Forms use this instead of a full-screen route so the conversation behind
/// stays visible: you keep reading the channel while you configure the thing
/// you are about to use in it. [child] is normally a [Scaffold] with an
/// [AppBar], which renders unchanged inside the panel.
Future<T?> showFormPanel<T>(
  BuildContext context, {
  required Widget child,
  double width = 580,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final available = MediaQuery.sizeOf(context).width - 120;
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width > available ? available : width,
          height: double.infinity,
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}
