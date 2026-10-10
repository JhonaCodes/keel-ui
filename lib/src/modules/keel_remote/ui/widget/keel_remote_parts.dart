import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';

/// The thin line that says something is being read, without moving a pixel
/// of what is already on screen.
class KeelLoadingBar extends StatelessWidget {
  const KeelLoadingBar({super.key, required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.5,
      child: loading ? const LinearProgressIndicator(minHeight: 1.5) : null,
    );
  }
}

/// A failure in words, in the error colour.
class KeelFailureText extends StatelessWidget {
  const KeelFailureText({super.key, required this.failure});

  final KeelApiFailure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        failure.message(AppLocalizations.of(context)),
        style: TextStyle(color: scheme.error, fontSize: 12.5),
      ),
    );
  }
}

/// A short title over a group of rows.
class KeelSectionTitle extends StatelessWidget {
  const KeelSectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// What a tab says while nobody is signed in.
class KeelSignInFirst extends StatelessWidget {
  const KeelSignInFirst({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).keelApiSignInFirst,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// A sentence for an empty list.
class KeelEmptyText extends StatelessWidget {
  const KeelEmptyText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}

/// Online or not, as a dot.
class KeelOnlineDot extends StatelessWidget {
  const KeelOnlineDot({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: online ? scheme.primary : scheme.outlineVariant,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The row on top of a tab: what it is, and its refresh button.
class KeelTabToolbar extends StatelessWidget {
  const KeelTabToolbar({
    super.key,
    required this.onRefresh,
    this.leading = const <Widget>[],
    this.trailing = const <Widget>[],
  });

  final VoidCallback onRefresh;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Row(
        children: [
          ...leading,
          const Spacer(),
          ...trailing,
          IconButton(
            tooltip: AppLocalizations.of(context).keelApiRefresh,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }
}
