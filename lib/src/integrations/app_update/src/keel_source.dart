part of '../app_update.dart';

/// Cuántas carpetas para arriba se busca antes de darse por vencido.
///
/// Desde el binario hasta la raíz del repo hay ocho
/// (`…/build/macos/Build/Products/Debug/Keel.app/Contents/MacOS/Keel`).
/// Doce deja lugar para una estructura de build distinta sin empezar a
/// escanear el disco entero.
const _kSearchDepth = 12;

/// El repo desde donde corre esta copia de Keel.
///
/// Es un dato y no una configuración: no hay campo que llenar ni ruta que
/// elegir. Si la copia que estás corriendo salió de un repo, se encuentra
/// sola subiendo desde el ejecutable; si la copiaste a `/Aplicaciones` sin
/// el código al lado, no se encuentra, y eso es exactamente lo que hay que
/// decir en vez de inventar una ruta.
class KeelSource {
  const KeelSource({this.root = '', this.builtAt});

  /// La raíz del repo, o vacío si esta copia no salió de uno que siga acá.
  final String root;

  /// Cuándo se construyó lo que estás corriendo — la fecha del ejecutable.
  final DateTime? builtAt;

  bool get found => root.isNotEmpty;
}

/// Sube desde [from] buscando la carpeta que [isRoot] reconozca.
///
/// Separado del disco a propósito: la parte que se puede equivocar es la
/// caminata, no el `existsSync`.
String keelRootAbove(
  String from,
  bool Function(String dir) isRoot, {
  int depth = _kSearchDepth,
}) {
  var dir = from;
  for (var step = 0; step < depth; step++) {
    if (isRoot(dir)) return dir;
    final parent = _parentOf(dir);
    if (parent == dir) return '';
    dir = parent;
  }
  return '';
}

String _parentOf(String dir) {
  final cut = dir.lastIndexOf('/');
  if (cut <= 0) return dir;
  return dir.substring(0, cut);
}

/// Una carpeta es la raíz del repo de Keel si tiene el `pubspec.yaml` de
/// Keel y un `.git`. Las dos cosas: `build/` de un checkout ajeno podría
/// tener lo primero, y cualquier repo del mundo tiene lo segundo.
bool looksLikeKeelRoot(String dir) {
  final pubspec = File('$dir/pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  if (!Directory('$dir/.git').existsSync()) return false;
  return pubspec.readAsStringSync().contains('name: keel_ui');
}

/// Encuentra el repo subiendo desde el ejecutable que está corriendo.
KeelSource readKeelSource() {
  final executable = Platform.resolvedExecutable;
  final root = keelRootAbove(_parentOf(executable), looksLikeKeelRoot);
  DateTime? builtAt;
  try {
    builtAt = File(executable).statSync().modified;
  } catch (_) {
    // Sin fecha se pierde el aviso de "estás corriendo algo viejo", no la
    // funcionalidad.
  }
  return KeelSource(root: root, builtAt: builtAt);
}
