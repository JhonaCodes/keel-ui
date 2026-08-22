part of '../system_vault.dart';

/// El respaldo que corre solo: cada tanto mientras trabajás, y una vez más
/// al cerrar.
///
/// Existe porque la protección real no es el botón — es no tener que
/// acordarse del botón. Llega hasta el commit LOCAL y no más: subir al
/// remoto lo dispara el usuario, y mientras no lo haga, el aviso de
/// [SystemVaultState.warning] dice cuántos respaldos quedaron de este lado.
class VaultAutoBackup {
  VaultAutoBackup._();

  /// Cada cuánto se respalda mientras la app está abierta. Como el zip es
  /// determinista, un rato sin cambios no escribe commit ni dispara la firma
  /// GPG: el tick sale gratis.
  static const _interval = Duration(minutes: 15);

  /// Cuánto se espera al respaldo de cierre antes de cerrar igual.
  ///
  /// La salida está frenada mientras esto corre. Un `git commit` que pide
  /// passphrase puede quedarse esperando a alguien que ya se fue, y una app
  /// que no cierra es peor que un respaldo perdido — el zip, que es lo que
  /// importa, ya se escribió antes de que git entre en juego.
  static const _closeBudget = Duration(seconds: 20);

  static Timer? _timer;
  static AppLifecycleListener? _listener;

  /// Arranca el respaldo automático. Solo en la ventana principal: es la
  /// única que tiene base de datos.
  ///
  /// El enganche de salida es [AppLifecycleListener.onExitRequested] y no
  /// `windowManager.setPreventClose`: ese último frena el cierre de la
  /// VENTANA, pero el quit de la APP (Cmd+Q, el menú, un AppleEvent) no pasa
  /// por ahí — queda cancelado y nadie lo vuelve a disparar, así que la app
  /// se vuelve imposible de cerrar. Probado, no supuesto.
  static void start() {
    _timer ??= Timer.periodic(_interval, (_) => unawaited(_backup()));
    _listener ??= AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  static Future<AppExitResponse> _onExitRequested() async {
    try {
      await _backup().timeout(_closeBudget);
    } catch (error) {
      Log.w('Respaldo de cierre incompleto: $error');
    }
    // Siempre se sale. Este enganche existe para alcanzar a guardar, no para
    // discutirle al usuario si puede cerrar.
    return AppExitResponse.exit;
  }

  static Future<void> _backup() async {
    await SettingsService.instance.notifier.ready;
    // Sin carpeta elegida no hay dónde respaldar, y no es un error: es una
    // instalación que todavía no configuró el vault.
    if (SettingsService.instance.notifier.data.vaultPath.trim().isEmpty) return;
    await SystemVaultService.instance.notifier.backup(
      reach: VaultReach.commit,
    );
  }
}
