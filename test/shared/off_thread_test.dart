import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/shared/shared.dart';

/// El trabajo que se va al otro isolate: de nivel superior, como corresponde.
int _square(int value) => value * value;

/// Un ViewModel de mentira con lo que hace fallar el copiado: un objeto que
/// no viaja. En la app de verdad ese objeto es la lista de listeners, que
/// lleva al árbol de widgets y de ahí a un `FocusNode`.
class _FakeViewModel {
  final port = ReceivePort();
  int seed = 7;

  /// El envoltorio que usan todos los ViewModels de la app: el cuerpo entero
  /// vive adentro de un closure, y ahí es donde se cuela `this`.
  Future<T> guarded<T>(Future<T> Function() body) => body();

  /// Como estaba escrito antes.
  Future<int> naive() => guarded(() async {
    final value = seed;
    return Isolate.run(() => _square(value));
  });

  Future<int> safe() => guarded(() async {
    final value = seed;
    return runOffThread(_square, value);
  });
}

void main() {
  late _FakeViewModel viewmodel;

  setUp(() => viewmodel = _FakeViewModel());
  tearDown(() => viewmodel.port.close());

  test('escrito adentro del método, el isolate se lleva el ViewModel', () {
    // Esto es el bug: la línea no nombra a `this` en ningún lado, pero el
    // contexto del closure de afuera sí lo tiene, y se copia entero.
    expect(
      viewmodel.naive(),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('unsendable'),
        ),
      ),
    );
  });

  test('con runOffThread viajan la función y su argumento, nada más', () async {
    expect(await viewmodel.safe(), 49);
  });
}
