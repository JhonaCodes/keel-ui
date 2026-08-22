part of '../catalog_shape.dart';

/// La carpeta del vault en ESTA máquina, o vacío si no hay ninguna elegida.
String get vaultRootPath =>
    SettingsService.instance.notifier.data.vaultPath.trim();

/// [absolutePath] visto desde [root], o null si no cuelga de él.
///
/// Es la única ruta que viaja en un export, y viaja justamente porque NO es
/// absoluta: del otro lado el vault está en otro lado y se vuelve a armar
/// contra la raíz de allá. La raíz exacta devuelve null a propósito — una
/// base que fuera el vault entero se contendría a sí misma.
String? relativeToRoot(String root, String absolutePath) {
  final base = root.trim();
  final path = absolutePath.trim();
  if (base.isEmpty || path.isEmpty) return null;

  final prefix = base.endsWith('/') ? base : '$base/';
  if (!path.startsWith(prefix)) return null;

  final relative = path.substring(prefix.length);
  return relative.isEmpty ? null : relative;
}

/// La ruta absoluta de [relative] dentro de [root], o null si no hay raíz o
/// si la relativa intenta salirse de ella.
String? absoluteFromRoot(String root, String relative) {
  final base = root.trim();
  final path = relative.trim();
  if (base.isEmpty || path.isEmpty) return null;
  // Una relativa que sube de nivel, o que es absoluta, no describe algo del
  // vault: viene de un archivo armado a mano y escribirla apuntaría afuera
  // del repo. Es la única defensa entre un zip ajeno y el disco.
  if (path.startsWith('/') || path.split('/').contains('..')) return null;

  final prefix = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$prefix/$path';
}

/// [absolutePath] visto desde el vault de esta máquina.
String? vaultRelativeOf(String absolutePath) =>
    relativeToRoot(vaultRootPath, absolutePath);

/// [relative] resuelta contra el vault de esta máquina.
String? vaultAbsoluteOf(String relative) =>
    absoluteFromRoot(vaultRootPath, relative);
