part of '../system_vault.dart';

/// Algo del vault salió mal de una forma que el usuario puede entender y
/// arreglar (no hay carpeta, git falló, el zip no es un respaldo).
class _VaultException implements Exception {
  final String message;
  const _VaultException(this.message);
}

Future<({bool ok, String output})> _git(
  List<String> args, {
  String? cwd,
}) async {
  final result = await Process.run('git', args, workingDirectory: cwd);
  final output = [
    (result.stdout as String).trim(),
    (result.stderr as String).trim(),
  ].where((part) => part.isNotEmpty).join('\n');
  return (ok: result.exitCode == 0, output: output);
}

/// Deja [dir] listo para recibir commits: repo git si no lo era, `.gitignore`
/// con lo que nunca debe subir, y `origin` apuntando a [remoteUrl].
///
/// Es idempotente a propósito: se llama en cada "Respaldar y subir", y la
/// primera vez tiene que poder arrancar de una carpeta suelta como
/// `~/keel-knowledge-bases`, que hoy no es un repo.
Future<void> ensureVaultRepo(String dir, String remoteUrl) async {
  if (!Directory('$dir/.git').existsSync()) {
    final init = await _git(['init'], cwd: dir);
    if (!init.ok) throw _VaultException('git init falló: ${init.output}');
  }

  final ignore = File('$dir/.gitignore');
  if (!ignore.existsSync()) {
    await ignore.writeAsString('.DS_Store\n');
  }

  final url = remoteUrl.trim();
  if (url.isEmpty) return;

  final existing = await _git(['remote', 'get-url', 'origin'], cwd: dir);
  final remote = existing.ok
      ? await _git(['remote', 'set-url', 'origin', url], cwd: dir)
      : await _git(['remote', 'add', 'origin', url], cwd: dir);
  if (!remote.ok) throw _VaultException('git remote falló: ${remote.output}');
}

/// Cuánto puede pesar el `.git` del vault antes de que valga la pena parar a
/// juntar la basura, en KiB.
///
/// Reescribir el commit deja el blob del zip anterior como objeto
/// inalcanzable: el `git log` muestra uno solo y el `.git` crece igual. La
/// poda es lo que lo achica de verdad, pero un `gc` completo en CADA
/// respaldo castiga cada clic con segundos de espera —el vault además lleva
/// las bases de saber en claro, así que son miles de archivos—. Con umbral,
/// el repo queda acotado y el `gc` corre cada varias decenas de respaldos.
const int _kVaultGcThresholdKiB = 50 * 1024;

/// Deja el vault con UN SOLO respaldo commiteado y lo sube.
///
/// No hay historial: cada respaldo REEMPLAZA al anterior, porque un commit
/// nuevo por respaldo es un blob nuevo entero del zip —no se diffea— y el
/// repo se vuelve un pasivo que crece solo.
///
/// "El respaldo salió idéntico" no es un error: es la respuesta correcta
/// cuando el zip determinista no cambió. Ahí no se reescribe nada (amendar
/// sin cambios igual produce un sha nuevo, y eso sería un force-push por
/// nada), pero el push se intenta lo mismo: la punta podría haber quedado
/// sin subir de un intento anterior que falló.
Future<String> commitVault(
  String dir, {
  required String message,
  required bool push,
}) async {
  final add = await _git(['add', '-A'], cwd: dir);
  if (!add.ok) throw _VaultException('git add falló: ${add.output}');

  final rewritten = await _writeSingleCommit(dir, message);
  if (rewritten) await _pruneVaultHistory(dir);

  if (!push) {
    return rewritten
        ? 'Reemplacé el respaldo commiteado del vault: queda uno solo.'
        : 'El respaldo salió idéntico al que ya estaba commiteado — no '
              'reescribí nada.';
  }

  // La punta se reescribe, así que un push normal sale rechazado. Con
  // `--force-with-lease` y NUNCA `--force` pelado: el lease es lo que impide
  // pisar un push hecho desde otra máquina — ahí falla con "stale info" y el
  // usuario se entera, que es lo que corresponde.
  final pushed = await _git([
    'push',
    '--force-with-lease',
    '-u',
    'origin',
    'HEAD',
  ], cwd: dir);
  if (!pushed.ok) throw _VaultException('git push falló: ${pushed.output}');
  return rewritten
      ? 'Reemplacé el respaldo del vault y lo subí: el remoto queda con este '
            'solo.'
      : 'El respaldo salió idéntico al que ya estaba; el remoto quedó '
            'sincronizado igual.';
}

/// Deja la rama con un único commit que contiene lo que ya está en el índice.
/// Devuelve si hubo que escribirlo.
///
/// Tres caminos, y cada uno existe por algo distinto:
/// - sin commits (vault recién inicializado) → commit normal;
/// - la punta YA es el commit raíz —el estado estacionario— → `--amend`;
/// - hay historia acumulada de antes → se borra la rama para que `HEAD` quede
///   sin nacer y el commit siguiente sea raíz. `--amend` no sirve acá: solo
///   orfana la punta y dejaría los commits anteriores alcanzables para
///   siempre, que es justo el pasivo que se viene a sacar.
///
/// Borrar la rama no toca el índice ni el árbol de trabajo: el zip sigue en
/// el disco, y si algo se cortara justo ahí el respaldo siguiente la vuelve
/// a crear.
Future<bool> _writeSingleCommit(String dir, String message) async {
  final counted = await _git(['rev-list', '--count', 'HEAD'], cwd: dir);
  final commits = counted.ok ? int.tryParse(counted.output.trim()) ?? 0 : 0;
  final changed = await vaultHasChanges(dir);

  // Nada nuevo Y la historia ya está colapsada: no hay nada que reescribir.
  if (!changed && commits == 1) return false;
  // Repo vacío y árbol vacío: no hay ni respaldo que commitear.
  if (!changed && commits == 0) return false;

  if (commits > 1) await _detachBranchFromHistory(dir);

  // Este commit lo inicia Keel sin una terminal interactiva. No debe heredar
  // `commit.gpgSign=true`: al abrir la app desde Finder el PATH puede no
  // contener `gpg` y tampoco hay una sesión segura para pedir el pinentry.
  // El override es solo para este comando; la configuración del usuario y
  // los commits que haga por su cuenta siguen intactos.
  final commit = await _git([
    'commit',
    '--no-gpg-sign',
    if (commits == 1) '--amend',
    '-m',
    message,
  ], cwd: dir);
  if (!commit.ok) throw _VaultException('git commit falló: ${commit.output}');
  return true;
}

/// Suelta la rama de su historia dejando `HEAD` sin nacer.
Future<void> _detachBranchFromHistory(String dir) async {
  final branch = await _git(['symbolic-ref', '--short', 'HEAD'], cwd: dir);
  if (!branch.ok) {
    throw _VaultException(
      'El vault no está parado sobre una rama (HEAD suelto): '
      '${branch.output}. Hacé `git switch -c main` en la carpeta del vault y '
      'volvé a respaldar.',
    );
  }
  final dropped = await _git([
    'update-ref',
    '-d',
    'refs/heads/${branch.output.trim()}',
  ], cwd: dir);
  if (!dropped.ok) {
    throw _VaultException('git update-ref falló: ${dropped.output}');
  }
}

/// Tira los objetos que quedaron inalcanzables al reescribir el commit.
///
/// Es limpieza, no el respaldo: si falla, el respaldo ya está commiteado y
/// decir que falló sería mentir. Queda en el registro para que no desaparezca
/// en silencio.
Future<void> _pruneVaultHistory(String dir) async {
  final expired = await _git([
    'reflog',
    'expire',
    '--expire=now',
    '--all',
  ], cwd: dir);
  if (!expired.ok) {
    Log.w('No pude expirar el reflog del vault: ${expired.output}');
    return;
  }

  final counted = await _git(['count-objects', '-v'], cwd: dir);
  if (!counted.ok) {
    Log.w('No pude medir el repo del vault: ${counted.output}');
    return;
  }
  if (_repoSizeKiB(counted.output) < _kVaultGcThresholdKiB) return;

  final collected = await _git(['gc', '--prune=now', '--quiet'], cwd: dir);
  if (!collected.ok) {
    Log.w('El gc del vault no terminó: ${collected.output}');
  }
}

/// Lo que ocupa el repo en disco según `git count-objects -v`, en KiB:
/// `size` son los objetos sueltos y `size-pack` los empaquetados.
int _repoSizeKiB(String countOutput) {
  var total = 0;
  for (final line in countOutput.split('\n')) {
    final parts = line.split(':');
    if (parts.length != 2) continue;
    if (parts.first.trim() case 'size' || 'size-pack') {
      total += int.tryParse(parts.last.trim()) ?? 0;
    }
  }
  return total;
}

/// Clona [url] en [destination], que tiene que no existir o estar vacío.
Future<void> cloneVaultRepo(String url, String destination) async {
  final target = Directory(destination);
  if (target.existsSync() && target.listSync().isNotEmpty) {
    throw _VaultException(
      'La carpeta destino no está vacía. Elegí una vacía o una que no '
      'exista: el clone tiene que traer el repo entero.',
    );
  }

  await target.parent.create(recursive: true);
  final clone = await _git(['clone', url, destination]);
  if (!clone.ok) throw _VaultException('git clone falló: ${clone.output}');
}

/// En qué estado está el vault respecto de git. Se consulta seguido (cada
/// respaldo, cada arranque) y nunca escribe nada.
typedef VaultRepoStatus = ({
  bool isRepo,
  bool hasRemote,
  bool hasUnpushedBackup,
});

const VaultRepoStatus _noRepo = (
  isRepo: false,
  hasRemote: false,
  hasUnpushedBackup: false,
);

/// Si el respaldo commiteado todavía no salió de esta máquina.
///
/// Es un sí o un no, no una cuenta: con un solo commit reescribiéndose,
/// "cuántos quedaron de este lado" no significa nada.
///
/// Sin upstream la cuenta son TODOS los commits: una rama que nunca se
/// pusheó está entera sin subir, y decir "está subido" ahí sería mentir
/// justo en el caso en que más importa.
Future<VaultRepoStatus> vaultRepoStatus(String dir) async {
  if (!Directory('$dir/.git').existsSync()) return _noRepo;

  final remote = await _git(['remote', 'get-url', 'origin'], cwd: dir);
  if (!remote.ok) {
    return (isRepo: true, hasRemote: false, hasUnpushedBackup: false);
  }

  final ahead = await _git(['rev-list', '--count', '@{u}..HEAD'], cwd: dir);
  final counted = ahead.ok
      ? ahead
      : await _git(['rev-list', '--count', 'HEAD'], cwd: dir);
  return (
    isRepo: true,
    hasRemote: true,
    hasUnpushedBackup: (int.tryParse(counted.output.trim()) ?? 0) > 0,
  );
}

/// Si hay algo sin commitear en [dir].
///
/// Se pregunta DESPUÉS del `git add -A` y antes de reescribir el commit: sin
/// cambios no se llama a `git commit`, y entonces ni se dispara la firma GPG
/// ni se reescribe la punta por nada. `--amend` sin cambios igual produce un
/// sha nuevo, así que sin esta pregunta cada respaldo idéntico se llevaría un
/// force-push de regalo.
Future<bool> vaultHasChanges(String dir) async {
  final status = await _git(['status', '--porcelain'], cwd: dir);
  return status.ok && status.output.trim().isNotEmpty;
}
