import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keel_ui/src/core/services/user_shell_path.dart';

/// Lo que se prueba acá es la resolución, no el shell.
///
/// El bug que esto cuida no se reproduce bajo `flutter test`: el test corre
/// desde una terminal, así que hereda el PATH bueno y todo "anda" igual. Lo
/// que sí se puede fijar es el contrato del que dependen los cuatro lugares
/// que lanzan CLIs — que [UserShellPath.locate] devuelva rutas absolutas
/// existentes, y null cuando el binario no está.
void main() {
  group('UserShellPath', () {
    test('devuelve un PATH con entradas', () async {
      final path = await UserShellPath.resolved();
      expect(path, isNotEmpty);
      expect(path.split(':').where((entry) => entry.isNotEmpty), isNotEmpty);
    });

    test('memoiza: dos lecturas dan exactamente lo mismo', () async {
      // Sin esto, los ocho probes de servicios abrirían ocho shells de login.
      expect(await UserShellPath.resolved(), await UserShellPath.resolved());
    });

    test('locate devuelve una ruta absoluta que existe', () async {
      // `sh` está en el PATH mínimo de cualquier máquina POSIX, así que este
      // caso no depende de qué tenga instalado quien corre el test.
      final located = await UserShellPath.locate('sh');
      expect(located, isNotNull);
      expect(located, startsWith(Platform.pathSeparator));
      expect(File(located!).existsSync(), isTrue);
    });

    test('locate devuelve null cuando el binario no está', () async {
      expect(await UserShellPath.locate('keel_binario_inexistente_xyz'), isNull);
    });

    test('locate deja pasar una ruta ya escrita', () async {
      // Un runtime configurado como `/usr/local/bin/python3` no se busca: ya
      // dijo dónde está.
      expect(await UserShellPath.locate('/bin/sh'), '/bin/sh');
    });

    test('environment trae solo PATH, para montarse sobre el heredado',
        () async {
      final environment = await UserShellPath.environment();
      expect(environment.keys, ['PATH']);
      expect(environment['PATH'], await UserShellPath.resolved());
    });
  });
}
