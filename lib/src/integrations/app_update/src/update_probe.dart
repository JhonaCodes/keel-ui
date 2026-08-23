part of '../app_update.dart';

Future<({bool ok, String output})> _git(
  List<String> args, {
  required String cwd,
}) async {
  final result = await Process.run('git', args, workingDirectory: cwd);
  final output = [
    '${result.stdout}'.trim(),
    '${result.stderr}'.trim(),
  ].where((part) => part.isNotEmpty).join('\n');
  return (ok: result.exitCode == 0, output: output);
}

/// Un commit del remoto que todavía no tenés.
typedef KeelCommit = ({String sha, String subject, DateTime at});

/// El separador entre campos. Se usa `\x1f` —el separador de unidades de
/// ASCII— y no un `|` porque el asunto de un commit puede traer cualquier
/// cosa, incluido un `|`.
const _kFieldSeparator = '\x1f';
const _kLogFormat = '--format=%h$_kFieldSeparator%s$_kFieldSeparator%cI';

/// Parte la salida de `git log` con [_kLogFormat]. Lo que no se entiende se
/// saltea: media lista es mejor que ninguna.
List<KeelCommit> parseCommitLog(String output) {
  final commits = <KeelCommit>[];
  for (final line in output.split('\n')) {
    final parts = line.split(_kFieldSeparator);
    if (parts.length < 3) continue;
    final at = DateTime.tryParse(parts[2].trim());
    if (at == null) continue;
    commits.add((sha: parts[0].trim(), subject: parts[1].trim(), at: at));
  }
  return commits;
}

/// En qué estado está el código de Keel.
class KeelVersion {
  const KeelVersion({
    this.branch = '',
    this.head = '',
    this.subject = '',
    this.at,
    this.builtAt,
    this.dirty = false,
    this.hasUpstream = false,
    this.incoming = const [],
    this.checkedAt,
  });

  final String branch;

  /// El commit en el que está el repo AHORA. Ojo: no es necesariamente el
  /// que estás corriendo — ver [stale].
  final String head;
  final String subject;
  final DateTime? at;

  /// Cuándo se construyó el binario abierto.
  final DateTime? builtAt;

  final bool dirty;
  final bool hasUpstream;

  /// Los commits que tiene el remoto y vos no, del más nuevo al más viejo.
  final List<KeelCommit> incoming;

  /// Cuándo se preguntó por última vez. Null = nunca.
  final DateTime? checkedAt;

  int get behind => incoming.length;
  bool get outdated => incoming.isNotEmpty;

  /// Estás corriendo código más viejo del que tenés en el disco.
  ///
  /// Pasa siempre después de actualizar —traer commits no reconstruye
  /// nada— y también cuando editaste el código a mano y no volviste a
  /// construir. Es la pregunta que nadie se hace y la que explica el "pero
  /// si ya lo arreglé".
  bool get stale {
    final built = builtAt;
    final commit = at;
    if (built == null || commit == null) return false;
    return built.isBefore(commit);
  }

  KeelVersion copyWith({
    List<KeelCommit>? incoming,
    DateTime? checkedAt,
    DateTime? builtAt,
  }) => KeelVersion(
    branch: branch,
    head: head,
    subject: subject,
    at: at,
    builtAt: builtAt ?? this.builtAt,
    dirty: dirty,
    hasUpstream: hasUpstream,
    incoming: incoming ?? this.incoming,
    checkedAt: checkedAt ?? this.checkedAt,
  );
}

/// Lee el estado del repo. Con [fetch] pregunta primero al remoto, que es
/// la única parte que necesita red.
Future<KeelVersion> readKeelVersion(
  KeelSource source, {
  bool fetch = true,
}) async {
  if (!source.found) return const KeelVersion();
  final root = source.root;

  final branch = await _git(['rev-parse', '--abbrev-ref', 'HEAD'], cwd: root);
  final head = await _git(['log', '-1', _kLogFormat], cwd: root);
  final status = await _git(['status', '--porcelain'], cwd: root);
  final upstream = await _git([
    'rev-parse',
    '--abbrev-ref',
    '@{u}',
  ], cwd: root);

  if (fetch && upstream.ok) {
    // Falla y sigue: sin red se muestra lo que se sabe del repo local, que
    // es la mitad útil de la respuesta.
    await _git(['fetch', '--quiet', 'origin'], cwd: root);
  }

  final incoming = upstream.ok
      ? await _git(['log', _kLogFormat, 'HEAD..@{u}'], cwd: root)
      : (ok: false, output: '');

  final actual = parseCommitLog(head.output).firstOrNull;
  return KeelVersion(
    branch: branch.ok ? branch.output.trim() : '',
    head: actual?.sha ?? '',
    subject: actual?.subject ?? '',
    at: actual?.at,
    builtAt: source.builtAt,
    dirty: status.ok && status.output.trim().isNotEmpty,
    hasUpstream: upstream.ok,
    incoming: incoming.ok ? parseCommitLog(incoming.output) : const [],
    checkedAt: DateTime.now(),
  );
}
