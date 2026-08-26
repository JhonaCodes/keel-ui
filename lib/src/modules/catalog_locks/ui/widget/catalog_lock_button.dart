import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';

/// The small direct-user control used by every catalog surface.
class CatalogLockButton extends StatelessWidget {
  const CatalogLockButton({
    super.key,
    required this.kind,
    required this.name,
    this.size,
    this.compact = false,
  });

  final CatalogLockKind kind;
  final String name;
  final double? size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<CatalogLocksViewModel, CatalogLocksState>(
      viewmodel: CatalogLocksService.instance.notifier,
      build: (state, viewmodel, keep) {
        final locked = viewmodel.isLocked(kind, name);
        return IconButton(
          tooltip: locked ? 'Desbloquear' : 'Bloquear',
          icon: Icon(
            locked ? Icons.lock : Icons.lock_open_outlined,
            size: size,
          ),
          constraints: compact
              ? BoxConstraints.tightFor(
                  width: (size ?? 18) + 10,
                  height: (size ?? 18) + 10,
                )
              : null,
          padding: compact ? EdgeInsets.zero : null,
          onPressed: () => viewmodel.setLocked(kind, name, locked: !locked),
        );
      },
    );
  }
}
