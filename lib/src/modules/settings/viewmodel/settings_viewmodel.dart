import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/repository/settings_repository.dart';

class SettingsViewModel extends ViewModel<AppSettings> {
  SettingsViewModel() : super(const AppSettings());

  SettingsRepository get _repository => SettingsRepository();

  /// Resuelve cuando los ajustes persistidos ya cargaron. Quien los lee
  /// fuera de un widget —la migración de bases de saber, por ejemplo— tiene
  /// que esperarlo: leer antes devuelve los valores por defecto y parece
  /// que el usuario no configuró nada.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedSettings();

  @override
  void init() {
    if (_ready == null) updateSilently(const AppSettings());
    unawaited(ready);
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final settings = await _repository.load();
      updateState(settings);
    } catch (error) {
      Log.e('Failed to load persisted settings', error: error);
    }
  }

  void setCatalogRepoUrl(String url) {
    updateState(data.copyWith(catalogRepoUrl: url.trim()));
    unawaited(_repository.save(data));
  }

  void setKnowledgeRepoUrl(String url) {
    updateState(data.copyWith(knowledgeRepoUrl: url.trim()));
    unawaited(_repository.save(data));
  }

  void setChatFontScale(double scale) {
    updateState(data.copyWith(chatFontScale: scale));
    unawaited(_repository.save(data));
  }

  void setExtraToolEnabled(String tool, bool enabled) {
    final tools = {...data.extraAllowedTools};
    if (enabled) {
      tools.add(tool);
    } else {
      tools.remove(tool);
    }
    updateState(data.copyWith(extraAllowedTools: tools.toList()));
    unawaited(_repository.save(data));
  }
}

mixin SettingsService {
  static final ReactiveNotifier<SettingsViewModel> instance =
      ReactiveNotifier<SettingsViewModel>(() => SettingsViewModel());
}
