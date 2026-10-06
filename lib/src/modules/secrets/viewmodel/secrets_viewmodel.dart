import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/secrets/model/secret.dart';
import 'package:keel_core/modules/secrets/service/secrets_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class SecretsViewModel extends StoreMirrorViewModel<SecretsState> {
  SecretsViewModel() : super(SecretsStore.instance);

  Future<void> get ready => SecretsStore.instance.ready;

  Map<String, String> valuesFor(List<String> names) =>
      SecretsStore.instance.valuesFor(names);

  Future<String?> resolveValue(String? name) =>
      SecretsStore.instance.resolveValue(name);

  List<String> pendingOf(List<String> names) =>
      SecretsStore.instance.pendingOf(names);

  List<String> missingOf(List<String> names) =>
      SecretsStore.instance.missingOf(names);

  String? createSecret({
    required String name,
    required String description,
    required String value,
  }) => SecretsStore.instance.createSecret(
    name: name,
    description: description,
    value: value,
  );

  String requestSecret({
    required String name,
    required String why,
    String? requestedByProfileId,
  }) => SecretsStore.instance.requestSecret(
    name: name,
    why: why,
    requestedByProfileId: requestedByProfileId,
  );

  String? updateSecret(
    String id, {
    required String name,
    required String description,
    required String value,
  }) => SecretsStore.instance.updateSecret(
    id,
    name: name,
    description: description,
    value: value,
  );

  void deleteSecret(String id) => SecretsStore.instance.deleteSecret(id);
}

mixin SecretsService {
  static final ReactiveNotifier<SecretsViewModel> instance =
      ReactiveNotifier<SecretsViewModel>(() => SecretsViewModel());
}
