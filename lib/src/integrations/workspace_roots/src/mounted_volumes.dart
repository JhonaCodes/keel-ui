part of '../workspace_roots.dart';

/// Los volúmenes montados en esta máquina, sin contar el de arranque.
///
/// Cada sistema los expone en un lugar distinto y ninguno tiene una API
/// portable: macOS los monta bajo `/Volumes`, Linux bajo `/media/$USER`,
/// `/run/media/$USER` o `/mnt`, y Windows los da como letras de unidad. Lo
/// único que hace esta función es mirar esos lugares y devolver los que
/// EXISTEN — no hay lista fija ni suposición sobre cómo se llama el disco de
/// nadie.
///
/// [platformRoots] existe para el test: la enumeración real depende del
/// disco de quien corre, así que la parte que se puede probar —filtrar lo
/// que no existe, ordenar, no repetir— se prueba contra un listado dado.
List<String> mountedVolumeRoots({
  List<String>? platformRoots,
  bool Function(String path)? exists,
}) {
  final candidates = platformRoots ?? _platformCandidates();
  final check = exists ?? (path) => Directory(path).existsSync();

  final roots = <String>[];
  for (final candidate in candidates) {
    final path = candidate.trim();
    if (path.isEmpty || roots.contains(path)) continue;
    if (!check(path)) continue;
    roots.add(path);
  }
  roots.sort();
  return roots;
}

List<String> _platformCandidates() {
  if (Platform.isWindows) {
    // Las 26 letras, y que exista decida. Preguntar es más barato que
    // cualquier API: una unidad que no está montada no responde y sale.
    return [
      for (
        var letter = 'A'.codeUnitAt(0);
        letter <= 'Z'.codeUnitAt(0);
        letter++
      )
        '${String.fromCharCode(letter)}:\\',
    ];
  }

  if (Platform.isMacOS) {
    // `/Volumes` tiene también un enlace al disco de arranque; se filtra
    // porque ya está cubierto por `/` y ofrecerlo dos veces confunde.
    final root = Directory('/Volumes');
    if (!root.existsSync()) return const [];
    return [
      for (final entry in _childrenOf(root))
        if (!_isBootVolumeLink(entry)) entry,
    ];
  }

  if (Platform.isLinux) {
    final user = Platform.environment['USER'] ?? '';
    final parents = [
      if (user.isNotEmpty) '/media/$user',
      if (user.isNotEmpty) '/run/media/$user',
      '/media',
      '/mnt',
    ];
    final roots = <String>[];
    for (final parent in parents) {
      final directory = Directory(parent);
      if (!directory.existsSync()) continue;
      roots.addAll(_childrenOf(directory));
    }
    return roots;
  }

  return const [];
}

/// Los hijos directos de [directory], sin seguir enlaces y sin explotar si
/// el volumen se desmontó entre la pregunta y la lectura.
List<String> _childrenOf(Directory directory) {
  try {
    return [
      for (final entry in directory.listSync(followLinks: false))
        if (entry is Directory) entry.path,
    ];
  } on FileSystemException catch (error) {
    Log.w('No pude listar ${directory.path}: $error');
    return const [];
  }
}

/// En macOS, `/Volumes/<nombre-del-disco>` suele ser un enlace a `/`.
bool _isBootVolumeLink(String path) {
  try {
    return Directory(path).resolveSymbolicLinksSync() == '/';
  } on FileSystemException {
    return false;
  }
}
