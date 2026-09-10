import 'package:flutter/material.dart';

/// La marca de Keel —el ícono de la app dentro de un cuadrito— para firmar
/// lo que escribió el SISTEMA y no una persona ni un agente.
///
/// Existe como widget y no como un `Image.asset` suelto en cada lugar porque
/// la firma tiene que ser la MISMA en todos: si la nota del hilo la dibuja de
/// un tamaño y el avatar de Keel AI de otro, dejan de leerse como la misma
/// cosa y el usuario pierde justamente la señal que esto aporta —«esto lo
/// dice la app»—.
///
/// [size] manda y el radio se deriva, igual que en `MemberAvatar`, para que
/// las dos marcas se alineen cuando aparecen en la misma columna.
class KeelMark extends StatelessWidget {
  const KeelMark({super.key, this.size = 28, this.background});

  final double size;

  /// El fondo del cuadrito. Por defecto, ninguno: el ícono ya trae el suyo.
  /// La nota del hilo lo usa para apoyar la marca sobre el tono que la
  /// enmarca.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      // El PNG trae mucho aire alrededor de la K —la marca ocupa cerca de la
      // mitad del lienzo— así que a 18px la letra queda de 7 y se lee como un
      // carácter suelto en vez de como el logo. El escalado recorta ese
      // margen para que la K llene el cuadrito, igual que el ícono llena el
      // avatar de un agente.
      child: Transform.scale(
        scale: 1.7,
        child: Image.asset(
          'assets/icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          // En un test de widget el bundle de assets puede no estar montado.
          // Un ícono que no carga no puede tumbar la burbuja que lo lleva: se
          // degrada a la marca tipográfica y el mensaje se sigue leyendo.
          errorBuilder: (context, _, _) => _LetterMark(size: size),
        ),
      ),
    );
  }
}

/// La K de Keel, para cuando el PNG no está disponible.
class _LetterMark extends StatelessWidget {
  const _LetterMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      color: scheme.surfaceContainerHighest,
      child: Text(
        'K',
        style: TextStyle(
          fontSize: size * 0.6,
          fontWeight: FontWeight.w700,
          height: 1,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
