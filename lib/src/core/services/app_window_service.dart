import 'package:logger_rs/logger_rs.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:keel_ui/src/core/services/app_window_arguments.dart';

/// Live sub-window controllers, keyed by [AppWindowArguments.businessId].
/// The controller is the ONLY vehicle for pushing a method call from the
/// main engine into a sub-window's engine, so whoever opens a window that
/// must receive pushes keeps it registered here.
final Map<String, WindowController> _controllersByBusinessId = {};

/// Opens a new native OS window running its own Flutter engine. [arguments]
/// decides (in the new engine's `main()`) which widget tree that window
/// runs — see [AppWindowArguments]. The returned controller is already
/// registered under the arguments' businessId.
///
/// **La ventana nace oculta y se muestra sola.** Mostrarla desde acá, apenas
/// creada, la deja visible mientras su engine todavía arranca: eso es el
/// rectángulo negro que aparecía la primera vez (la segunda no, porque ahí
/// la ventana ya existía pintada). Quien la muestra es su propio `main()`,
/// después del primer frame — ver `_showWhenPainted` en `main.dart`.
Future<WindowController> openAppWindow(AppWindowArguments arguments) async {
  final controller = await WindowController.create(
    WindowConfiguration(
      hiddenAtLaunch: true,
      arguments: arguments.toArguments(),
    ),
  );
  _controllersByBusinessId[arguments.businessId] = controller;
  return controller;
}

/// Opens the window for [arguments], or focuses it if one with the same
/// businessId is already alive — the registry acts as the "only one window
/// of this kind" guarantee. Returns the (possibly pre-existing) controller.
Future<WindowController> openOrFocusAppWindow(
  AppWindowArguments arguments,
) async {
  final existing = await liveWindowController(arguments.businessId);
  if (existing != null) {
    await existing.show();
    return existing;
  }
  return openAppWindow(arguments);
}

/// The registered controller for [businessId] IF its native window still
/// exists, else null (cleaning up the stale entry). Verified against
/// [WindowController.getAll] because 0.3.0 offers no close callback on the
/// controller itself — the window dies natively without telling Dart.
Future<WindowController?> liveWindowController(String businessId) async {
  final registered = _controllersByBusinessId[businessId];
  if (registered == null) return _adoptLiveWindow(businessId);

  final all = await WindowController.getAll();
  final isAlive = all.any(
    (controller) => controller.windowId == registered.windowId,
  );
  if (isAlive) return registered;

  _controllersByBusinessId.remove(businessId);
  return null;
}

/// After a hot-restart of the main engine the registry is empty but the
/// sub-window may still be alive — re-adopt it by scanning the live windows'
/// launch arguments for the matching businessId.
Future<WindowController?> _adoptLiveWindow(String businessId) async {
  for (final controller in await WindowController.getAll()) {
    final json = AppWindowArguments.decode(controller.arguments);
    if (json?['businessId'] == businessId) {
      _controllersByBusinessId[businessId] = controller;
      return controller;
    }
  }
  return null;
}

/// Pushes [method] into the sub-window registered under [businessId].
/// Returns true if the call reached a live window. A dead window is never
/// an error for the caller — it just means nobody is listening anymore, and
/// the stale registration is dropped.
Future<bool> invokeOnWindow(
  String businessId,
  String method, [
  dynamic arguments,
]) async {
  final controller = await liveWindowController(businessId);
  if (controller == null) return false;

  try {
    await controller.invokeMethod(method, arguments);
    return true;
  } catch (error) {
    Log.w('Push "$method" to window $businessId failed: $error');
    _controllersByBusinessId.remove(businessId);
    return false;
  }
}
