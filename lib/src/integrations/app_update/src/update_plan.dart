part of '../app_update.dart';

/// Lo que hace falta para traer la versión nueva, y lo que lo impide.
///
/// Los motivos son datos y no excepciones, igual que al unificar un
/// worktree: una operación que toca el repo desde donde corre la app se
/// mira entera antes de empezar.
class KeelUpdatePlan {
  const KeelUpdatePlan({
    required this.source,
    required this.version,
    this.running = 0,
  });

  final KeelSource source;
  final KeelVersion version;

  /// Sesiones corriendo en toda la app. No impiden traer los commits —el
  /// repo de Keel no es el repo de tus proyectos— pero sí reconstruir, que
  /// cierra la app con los turnos a medias.
  final int running;

  /// Por qué no se puede traer nada, en el orden en que conviene
  /// arreglarlo.
  List<String> get blockers => [
    if (!source.found)
      'Esta copia de Keel no tiene su código al lado: subí desde el '
          'ejecutable y no encontré el repo. Actualizala desde donde la '
          'construiste.',
    if (source.found && !version.hasUpstream)
      'La rama `${version.branch}` no sigue a ninguna del remoto, así que no '
          'hay con qué comparar. Enlazala con `git push -u origin '
          '${version.branch}` o pasate a una que ya lo esté.',
    if (version.dirty)
      'El repo de Keel tiene cambios sin commitear. Un `pull` con eso encima '
          'se niega, y con razón: commitealos o guardalos antes.',
  ];

  bool get canRun => blockers.isEmpty && version.outdated;

  /// Reconstruir cierra la app. Con turnos corriendo eso es cortarlos por la
  /// mitad.
  bool get canRelaunch => running == 0 && source.found;

  /// El estado en una línea — lo que se lee sin abrir nada.
  String get headline {
    if (!source.found) return 'No encuentro el código de esta copia.';
    if (version.outdated) {
      return version.behind == 1
          ? 'Hay 1 commit nuevo en `${version.branch}`.'
          : 'Hay ${version.behind} commits nuevos en `${version.branch}`.';
    }
    if (version.stale) {
      return 'El código está al día, pero estás corriendo una construcción '
          'anterior.';
    }
    return 'Estás en la última.';
  }
}
