part of '../workspace_roots.dart';

/// Una carpeta que el usuario eligió alguna vez, con cuándo fue la última.
class WorkspaceRoot {
  final String path;
  final DateTime lastUsedAt;

  const WorkspaceRoot({required this.path, required this.lastUsedAt});

  /// La clave del registro en la base local.
  ///
  /// No es la ruta: una ruta trae barras, dos puntos, espacios y acentos, y
  /// una clave no es lugar para nada de eso. Se guarda un slug legible más
  /// una huella de la ruta COMPLETA, así dos carpetas que se llaman igual en
  /// discos distintos no se pisan.
  String get id {
    final slug = path
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final short = slug.length <= 60 ? slug : slug.substring(slug.length - 60);
    return '${short}_${_fingerprint(path)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };

  factory WorkspaceRoot.fromJson(Map<String, dynamic> json) {
    return WorkspaceRoot(
      path: json['path'] as String,
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceRoot &&
          path == other.path &&
          lastUsedAt == other.lastUsedAt;

  @override
  int get hashCode => Object.hash(path, lastUsedAt);
}

/// FNV-1a de 32 bits, en hexadecimal.
///
/// `String.hashCode` no sirve acá: Dart no garantiza que sea el mismo entre
/// dos ejecuciones, y una clave que cambia de valor al reabrir la app es una
/// fila duplicada por arranque.
String _fingerprint(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

class WorkspaceRootsState {
  /// De más reciente a más vieja.
  final List<WorkspaceRoot> roots;

  const WorkspaceRootsState({this.roots = const []});

  WorkspaceRootsState copyWith({List<WorkspaceRoot>? roots}) =>
      WorkspaceRootsState(roots: roots ?? this.roots);
}
