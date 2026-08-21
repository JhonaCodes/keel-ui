import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';

class SettingsRepository {
  static const _key = 'settings';

  Future<AppSettings> load() async {
    final data = await LocalDatabase.get(_key);
    if (data == null) return const AppSettings();
    return AppSettings.fromJson(data);
  }

  Future<void> save(AppSettings settings) async {
    await LocalDatabase.put(_key, settings.toJson());
  }
}
