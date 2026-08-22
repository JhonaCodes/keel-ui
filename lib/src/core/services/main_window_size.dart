import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';

import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/repository/settings_repository.dart';

/// Abre la ventana principal con el tamaño que el usuario dejó la última
/// vez, y lo recuerda cuando la redimensiona.
///
/// El tamaño nativo viene del xib y es chico: tres columnas (rail, sidebar,
/// conversación) no entran, y el chat queda como una ranura. Acá se fija un
/// tamaño inicial usable y un mínimo por debajo del cual el layout deja de
/// tener sentido.
class MainWindowSize with WindowListener {
  MainWindowSize._();

  static final MainWindowSize _instance = MainWindowSize._();

  /// Se persiste con retraso: redimensionar dispara decenas de eventos por
  /// segundo y no hace falta escribir en cada píxel.
  static const _saveDelay = Duration(milliseconds: 600);

  Timer? _pendingSave;

  static SettingsRepository get _repository => SettingsRepository();

  /// Aplica el tamaño guardado y deja la ventana lista para mostrarse.
  /// Se llama ANTES de `runApp`, solo en la ventana principal.
  static Future<void> restore() async {
    final settings = await _repository.load();
    final size = Size(settings.windowWidth, settings.windowHeight);

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: size,
        minimumSize: const Size(kMinWindowWidth, kMinWindowHeight),
        center: true,
        // El título de la ventana, que hasta ahora salía del nombre del
        // binario: se veía "keel_ui" en el conmutador de ventanas.
        title: 'Keel',
        // Esta ventana se muestra ANTES de `runApp`, así que hay un hueco
        // real entre que aparece y que Flutter pinta. Con el fondo nativo
        // puesto, ese hueco es el color de la app y no un rectángulo negro.
        backgroundColor: AppColors.bg,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );

    windowManager.addListener(_instance);
  }

  @override
  void onWindowResized() => _instance._scheduleSave();

  @override
  void onWindowMaximize() => _instance._scheduleSave();

  @override
  void onWindowUnmaximize() => _instance._scheduleSave();

  void _scheduleSave() {
    _pendingSave?.cancel();
    _pendingSave = Timer(_saveDelay, _save);
  }

  Future<void> _save() async {
    final size = await windowManager.getSize();
    // Una ventana minimizada reporta un tamaño que no queremos persistir:
    // volver a abrirla así es peor que el default.
    if (size.width < kMinWindowWidth || size.height < kMinWindowHeight) return;

    final settings = await _repository.load();
    await _repository.save(
      settings.copyWith(windowWidth: size.width, windowHeight: size.height),
    );
  }
}
