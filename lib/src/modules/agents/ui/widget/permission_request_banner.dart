import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Lo que un agente te pide para poder seguir.
///
/// Los botones NO se deshabilitan porque el turno esté corriendo, y ese es
/// el punto: mientras hay un pedido en pantalla, el turno está corriendo
/// JUSTAMENTE porque te está esperando. La tool que lo pidió está suspendida
/// hasta que contestes. Atarlos a `isStreaming` —como estaban— dejaba los
/// dos botones grises hasta que el pedido expiraba solo a los diez minutos:
/// la única forma de contestar era no poder contestar.
///
/// Lo único que los apaga es haber contestado ya, para que un doble click no
/// mande la respuesta dos veces en el instante que la tarjeta tarda en irse.
class PermissionRequestBanner extends StatefulWidget {
  const PermissionRequestBanner({
    super.key,
    required this.request,
    required this.onRespond,
  });

  final PermissionRequest request;
  final void Function(bool grant) onRespond;

  @override
  State<PermissionRequestBanner> createState() =>
      _PermissionRequestBannerState();
}

class _PermissionRequestBannerState extends State<PermissionRequestBanner> {
  bool _answered = false;

  void _respond(bool grant) {
    if (_answered) return;
    setState(() => _answered = true);
    widget.onRespond(grant);
  }

  @override
  void didUpdateWidget(PermissionRequestBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otro pedido, otra decisión: la tarjeta se reusa y no puede quedar
    // apagada por la respuesta anterior.
    if (oldWidget.request != widget.request) _answered = false;
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final busy = _answered;
    final onRespond = _respond;
    final scheme = Theme.of(context).colorScheme;
    // Un bloqueo de hook NO se destraba con un permiso: no fue el permiso lo
    // que frenó. Ofrecer "permitir" ahí manda al usuario a prender un ajuste
    // global que no cambia nada, y a quedarse sin entender por qué.
    if (request.isHookDenial) {
      return _HookDenialBanner(request: request);
    }

    if (request.isCatalogChange) {
      return _CatalogChangePermissionBanner(
        request: request,
        busy: busy,
        onRespond: onRespond,
      );
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

class _CatalogChangePermissionBanner extends StatelessWidget {
  const _CatalogChangePermissionBanner({
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
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                children: [
                  Icon(Icons.lock_outline, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cambio sobre un elemento bloqueado',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CatalogDetail(
                label: 'Elemento',
                value: '${request.kind} · ${request.itemName}',
              ),
              _CatalogDetail(
                label: 'Intención',
                value: request.changeIntent ?? '',
              ),
              _CatalogDetail(
                label: 'Motivo',
                value: request.changeReason ?? '',
              ),
              _CatalogDetail(
                label: 'Solicitado por',
                value: request.requestedBy ?? 'Keel AI',
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
                    child: const Text('Aprobar cambio'),
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

class _CatalogDetail extends StatelessWidget {
  const _CatalogDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      '$label: $value',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
      ),
    ),
  );
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
