/// `SettingsRepository` now lives in `keel_core`, over `KeelStore` instead
/// of talking to `LocalDatabase` directly — re-exported here so existing
/// imports of this path keep working unchanged.
export 'package:keel_core/modules/settings/repository/settings_repository.dart';
