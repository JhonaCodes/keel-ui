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
    // Un bloqueo de hook NO se destraba con un permiso: no fue el permiso lo
    // que frenó. Ofrecer "permitir" ahí manda al usuario a prender un ajuste
    // global que no cambia nada, y a quedarse sin entender por qué.
    if (request.isHookDenial) {
      return _HookDenialBanner(request: request);
    }

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

/// Lo frenó un guardarraíl, no un permiso.
///
/// No tiene botón de conceder a propósito: lo que corresponde es mirar el
/// hook. Si sobra, se apaga desde su pantalla — o se le pide a Keel AI, que
/// corre sin hooks justamente para poder destrabar esto.
class _HookDenialBanner extends StatelessWidget {
  const _HookDenialBanner({required this.request});

  final PermissionRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hookName = request.blockingHookName;

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
              side: BorderSide(color: scheme.error.withValues(alpha: 0.35)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 18, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hookName == null
                          ? 'Un hook frenó ${request.toolName}.'
                          : 'El hook "$hookName" frenó ${request.toolName}.',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.message,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay permiso que conceder: esto lo decidió un '
                      'guardarraíl. Si sobra, apagalo en Hooks — o pedíselo '
                      'a Keel AI, que corre sin hooks.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
