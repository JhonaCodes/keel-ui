import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/shared/shared.dart';

class PermissionRequestBanner extends StatelessWidget {
  const PermissionRequestBanner({
    super.key,
    required this.request,
    required this.busy,
    required this.onRespond,
  });

  final PermissionRequest request;
  final bool busy;
  final void Function(bool grant) onRespond;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grantLabel = request.isSandboxRestriction
        ? 'Dar acceso a todo el disco'
        : 'Permitir ${request.toolName}';

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh,
            shape: 16.smoothBorder(
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      request.message,
                      style: TextStyle(color: scheme.onSurface, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => onRespond(false),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: busy ? null : () => onRespond(true),
                    child: Text(grantLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
