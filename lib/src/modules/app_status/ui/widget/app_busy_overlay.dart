import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/app_status/model/app_status.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';

/// La franja de 2px arriba de todo mientras la app trabaja, y la pantalla
/// atenuada solo cuando lo que corre te pisaría.
///
/// Dos niveles, no uno. Restaurar un respaldo reemplaza el sistema abajo
/// tuyo: ahí el `AbsorbPointer` es la diferencia entre esperar y perder
/// trabajo. Escribir un zip cada quince minutos no le hace nada a nadie, y
/// atenuar la app por eso era una interrupción sin razón detrás —además de
/// enseñarte a ignorar el aviso justo cuando sí importa.
///
/// Va montado en el `builder:` del `MaterialApp`, que es el único lugar que
/// cubre la app entera —incluidos los paneles laterales, que son rutas del
/// mismo Navigator— sin obligar a ninguna pantalla a saber que existe.
///
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
            // Solo lo que te pisaría atenúa y se traga los clicks. El
            // `AbsorbPointer` no es decorativo: sin él, los clicks que hacés
            // mientras arranca se encolan y se disparan todos juntos cuando
            // se destraba, abriendo tres paneles que nadie pidió.
            if (state.busy)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: scheme.scrim.withValues(alpha: 0.45),
                  ),
                ),
              ),
            if (state.busy || state.working) ...[
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
