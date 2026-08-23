part of '../shared.dart';

/// Corre [work] con [payload] en otro isolate, sin arrastrar el objeto que lo
/// pidió.
///
/// Parece un rodeo y no lo es. `Isolate.run(() => f(x))` escrito ADENTRO de un
/// método captura el contexto del método, y en ese contexto está `this` — aun
/// cuando la línea no lo nombre. Si ese `this` es un ViewModel, sus listeners
/// llevan al árbol de widgets, el árbol tiene `FocusNode`, y el copiado falla
/// con cincuenta líneas de `<- _child in Instance of ...` que no nombran ni
/// una vez al culpable.
///
/// Escrito acá arriba no hay `this` que capturar: viajan la función y su
/// argumento, que es todo lo que hacía falta. [work] tiene que ser una función
/// de nivel superior o estática, y [payload] tiene que ser sendable.
Future<R> runOffThread<T, R>(R Function(T) work, T payload) =>
    Isolate.run(() => work(payload));
