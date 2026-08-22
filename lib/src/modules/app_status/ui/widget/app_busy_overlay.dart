import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/app_status/model/app_status.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';

/// La franja de 2px arriba de todo y la pantalla atenuada, mientras la app
/// está ocupada.
///
/// Va montado en el `builder:` del `MaterialApp`, que es el único lugar que
/// cubre la app entera —incluidos los paneles laterales, que son rutas del
/// mismo Navigator— sin obligar a ninguna pantalla a saber que existe.
///
/// El `AbsorbPointer` no es decorativo: sin él, los clicks que hacés
/// mientras arranca se encolan y se disparan todos juntos cuando se
/// destraba, abriendo tres paneles que nadie pidió.
class AppBusyOverlay extends StatelessWidget {
  const AppBusyOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AppStatusViewModel, AppStatusState>(
      viewmodel: AppStatusService.instance.notifier,
      build: (state, viewmodel, keep) {
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          fit: StackFit.expand,
          children: [
            keep(child),
            if (state.busy) ...[
              // Atenuar en vez de tapar: se ve que la app está ahí y que le
              // falta poco, que es distinto de una pantalla de carga.
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: scheme.scrim.withValues(alpha: 0.45),
                  ),
                ),
              ),
              // Pegada arriba, sin ocupar layout: aparece y desaparece sin
              // mover un solo píxel de lo que hay debajo.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
              if (state.label != null)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                      ),
                      child: Text(state.label!),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
