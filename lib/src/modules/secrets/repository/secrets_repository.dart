import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';

class SecretsRepository {
  static const _prefix = 'secret_';

  Future<List<Secret>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Secret.fromJson).toList();
  }

  Future<void> save(List<Secret> secrets) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      secrets.map((secret) => secret.toJson()).toList(),
    );
  }
}
