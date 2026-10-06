import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/settings/model/app_settings.dart';
import 'package:keel_core/modules/settings/service/settings_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class SettingsViewModel extends StoreMirrorViewModel<AppSettings> {
  SettingsViewModel() : super(SettingsStore.instance);

  Future<void> get ready => SettingsStore.instance.ready;

  void setVaultPath(String path) => SettingsStore.instance.setVaultPath(path);

  void setVaultRepoUrl(String url) =>
      SettingsStore.instance.setVaultRepoUrl(url);

  void markVaultOnboardingDone() =>
      SettingsStore.instance.markVaultOnboardingDone();

  void setKnowledgeRepoUrl(String url) =>
      SettingsStore.instance.setKnowledgeRepoUrl(url);

  void setChatFontScale(double scale) =>
      SettingsStore.instance.setChatFontScale(scale);

  /// `'en'`, `'es_CO'`, o `''` para seguir el idioma del sistema.
  void setLanguage(String language) =>
      SettingsStore.instance.setLanguage(language);

  void applyRestored(AppSettings restored) =>
      SettingsStore.instance.applyRestored(restored);

  void setCodexSettings(CodexSettings codex) =>
      SettingsStore.instance.setCodexSettings(codex);

  void setExtraToolEnabled(String tool, bool enabled) =>
      SettingsStore.instance.setExtraToolEnabled(tool, enabled);
}

mixin SettingsService {
  static final ReactiveNotifier<SettingsViewModel> instance =
      ReactiveNotifier<SettingsViewModel>(() => SettingsViewModel());
}
