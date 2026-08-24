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

/// Commitea todo lo que haya en [dir] y lo sube.
///
/// "Nada que commitear" no es un error: es la respuesta correcta cuando el
/// respaldo salió idéntico al anterior, que es justamente lo que busca el
/// zip determinista. Aun así se intenta el push, porque un commit anterior
/// podría haber quedado sin subir.
Future<String> commitVault(
  String dir, {
  required String message,
  required bool push,
}) async {
  final add = await _git(['add', '-A'], cwd: dir);
  if (!add.ok) throw _VaultException('git add falló: ${add.output}');

  // Este commit lo inicia Keel sin una terminal interactiva. No debe heredar
  // `commit.gpgSign=true`: al abrir la app desde Finder el PATH puede no
  // contener `gpg` y tampoco hay una sesión segura para pedir el pinentry.
  // El override es solo para este comando; la configuración del usuario y
  // los commits que haga por su cuenta siguen intactos.
  final commit = await _git([
    'commit',
    '--no-gpg-sign',
    '-m',
    message,
  ], cwd: dir);
  final nothingToCommit = commit.output.contains('nothing to commit');
  if (!commit.ok && !nothingToCommit) {
    throw _VaultException('git commit falló: ${commit.output}');
  }

  if (!push) {
    return commit.ok
        ? 'Commiteé el respaldo en el vault.'
        : 'El vault ya estaba al día — no hubo nada que commitear.';
  }

  final pushed = await _git(['push', '-u', 'origin', 'HEAD'], cwd: dir);
  if (!pushed.ok) throw _VaultException('git push falló: ${pushed.output}');
  return commit.ok
      ? 'Commiteé y subí el respaldo.'
      : 'El vault ya estaba al día; el remoto quedó sincronizado igual.';
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
typedef VaultRepoStatus = ({bool isRepo, bool hasRemote, int unpushed});

const VaultRepoStatus _noRepo = (isRepo: false, hasRemote: false, unpushed: 0);

/// Cuántos respaldos commiteados todavía no salieron de esta máquina.
///
/// Sin upstream la cuenta son TODOS los commits: una rama que nunca se
/// pusheó está entera sin subir, y decir "0 pendientes" ahí sería mentir
/// justo en el caso en que más importa.
Future<VaultRepoStatus> vaultRepoStatus(String dir) async {
  if (!Directory('$dir/.git').existsSync()) return _noRepo;

  final remote = await _git(['remote', 'get-url', 'origin'], cwd: dir);
  if (!remote.ok) return (isRepo: true, hasRemote: false, unpushed: 0);

  final ahead = await _git(['rev-list', '--count', '@{u}..HEAD'], cwd: dir);
  if (ahead.ok) {
    return (
      isRepo: true,
      hasRemote: true,
      unpushed: int.tryParse(ahead.output.trim()) ?? 0,
    );
  }

  final all = await _git(['rev-list', '--count', 'HEAD'], cwd: dir);
  return (
    isRepo: true,
    hasRemote: true,
    unpushed: int.tryParse(all.output.trim()) ?? 0,
  );
}

/// Si hay algo sin commitear en [dir].
///
/// Se pregunta ANTES de commitear en el respaldo automático: sin cambios no
/// se llama a `git commit`, y entonces la firma GPG no se dispara. Con un
/// respaldo cada 15 minutos, commitear a ciegas sería un pinentry cada 15
/// minutos.
Future<bool> vaultHasChanges(String dir) async {
  final status = await _git(['status', '--porcelain'], cwd: dir);
  return status.ok && status.output.trim().isNotEmpty;
}
