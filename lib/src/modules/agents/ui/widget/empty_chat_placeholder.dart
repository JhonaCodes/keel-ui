import 'package:flutter/material.dart';

/// El área central cuando no hay nada abierto.
///
/// Es el único lugar de la app donde entra la marca. No es decoración: es la
/// pantalla que ves recién instalado, y la que queda cuando cerrás todo, así
/// que es donde un logo dice algo en vez de ocupar lugar.
class EmptyChatPlaceholder extends StatelessWidget {
  const EmptyChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bajo, no al 100%: el logo viene con su propio fondo casi negro y
          // a tamaño grande compite con la app en vez de acompañarla.
          Opacity(
            opacity: 0.55,
            child: Image.asset(
              'assets/icon.png',
              width: 92,
              height: 92,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Elegí un proyecto, o creá un agente con el +',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Keel AI, arriba a la izquierda, arma lo que le pidas.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
