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
        unpushedCommits: 1,
      );
      expect(state.warning, 'Hay 1 respaldo commiteado sin subir al remoto.');
    });

    test('varios sin subir se cuentan', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
        unpushedCommits: 4,
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
        unpushedCommits: 9,
      );
      expect(state.warning, contains('no tiene remoto'));
    });
  });
}
