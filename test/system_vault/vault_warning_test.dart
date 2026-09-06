import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';

final _stamp = DateTime.utc(2026, 8, 22, 10);

void main() {
  group('SystemVaultState.warning', () {
    test('sin carpeta elegida, lo dice sin rodeos', () {
      const state = SystemVaultState();
      expect(state.warningAt(_stamp), contains('No elegiste carpeta'));
      expect(state.needsAttentionAt(_stamp), isTrue);
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
      expect(state.warningAt(_stamp), contains('La última operación del vault falló'));
      expect(state.warningAt(_stamp), contains('unsendable'));
      expect(state.needsAttentionAt(_stamp), isTrue);
    });

    test('y desaparece en cuanto uno sale bien', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
        lastFailure: 'algo',
      ).copyWith(clearFailure: true);
      expect(state.warningAt(_stamp), isNull);
    });

    test('con carpeta pero sin ningún respaldo todavía', () {
      const state = SystemVaultState(configured: true);
      expect(state.warningAt(_stamp), contains('Todavía no hay ningún respaldo'));
    });

    test('respaldo escrito en una carpeta que no es repo', () {
      final state = SystemVaultState(configured: true, lastBackupAt: _stamp);
      expect(state.warningAt(_stamp), contains('no es un repo git'));
    });

    test('repo sin remoto: el respaldo no sale de la máquina', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
      );
      expect(state.warningAt(_stamp), contains('no tiene remoto'));
    });

    test('el respaldo commiteado que no salió de la máquina se dice', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
        hasUnpushedBackup: true,
      );
      expect(state.warningAt(_stamp), contains('no está subido al remoto'));
    });

    test('todo subido y recién hecho no avisa nada', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
      );
      expect(state.warningAt(_stamp), isNull);
      expect(state.needsAttentionAt(_stamp), isFalse);
    });

    test('el aviso contesta el primer peldaño que falla, no el último', () {
      // Sin remoto Y sin subir: lo que hay que arreglar primero es el
      // remoto, y hablar de "sin subir" ahí no ayudaría a nadie.
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasUnpushedBackup: true,
      );
      expect(state.warningAt(_stamp), contains('no tiene remoto'));
    });

    test('un respaldo viejo se avisa, aunque esté subido', () {
      // La red que reemplaza al respaldo automático: ahora nada corre solo,
      // así que un vault perfecto con un zip de la semana pasada se veía
      // exactamente igual que uno al día.
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
      );
      expect(
        state.warningAt(_stamp.add(const Duration(days: 6))),
        contains('hace 6 días'),
      );
      expect(state.needsAttentionAt(_stamp.add(const Duration(days: 6))), isTrue);
    });

    test('un respaldo de ayer todavía no molesta', () {
      final state = SystemVaultState(
        configured: true,
        lastBackupAt: _stamp,
        isRepo: true,
        hasRemote: true,
      );
      expect(state.warningAt(_stamp.add(const Duration(days: 1))), isNull);
    });
  });
}
