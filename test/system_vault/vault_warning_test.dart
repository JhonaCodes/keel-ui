import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';

final _stamp = DateTime.utc(2026, 8, 22, 10);

void main() {
  group('SystemVaultState.warning', () {
    test('sin carpeta elegida, lo dice sin rodeos', () {
      const state = SystemVaultState();
      expect(state.warning, contains('No elegiste carpeta'));
      expect(state.needsAttention, isTrue);
    });

    test('un respaldo que reventó gana sobre todo lo demás', () {
      // El caso que estuvo callado durante horas: el zip viejo sigue en el
      // disco con su fecha, el repo está al día, y el respaldo automático
      // viene fallando cada quince minutos sin que nada lo diga.
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
        lastFailure: 'El vault falló: object is unsendable',
      );
      expect(state.warning, contains('La última operación del vault falló'));
      expect(state.warning, contains('unsendable'));
      expect(state.needsAttention, isTrue);
    });

    test('y desaparece en cuanto uno sale bien', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
        lastFailure: 'algo',
      ).copyWith(clearFailure: true);
      expect(state.warning, isNull);
    });

    test('con carpeta pero sin ningún respaldo todavía', () {
      const state = SystemVaultState(configured: true);
      expect(state.warning, contains('Todavía no hay ningún respaldo'));
    });

    test('respaldo escrito en una carpeta que no es repo', () {
      final state = SystemVaultState(configured: true, lastBackupAt: _stamp);
      expect(state.warning, contains('no es un repo git'));
    });

    test('repo sin remoto: el respaldo no sale de la máquina', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
      );
      expect(state.warning, contains('no tiene remoto'));
    });

    test('uno sin subir se dice en singular', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
      );
      expect(state.warning, 'Hay 1 respaldo commiteado sin subir al remoto.');
    });

    test('varios sin subir se cuentan', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
      );
      expect(state.warning, contains('4 respaldos'));
    });

    test('todo subido no avisa nada', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
      );
      expect(state.warning, isNull);
      expect(state.needsAttention, isFalse);
    });

    test('el aviso contesta el primer peldaño que falla, no el último', () {
      // Sin remoto Y con commits contados: lo que hay que arreglar primero
      // es el remoto, y hablar de "sin subir" ahí no ayudaría a nadie.
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
      );
      expect(state.warning, contains('no tiene remoto'));
    });
  });
}
