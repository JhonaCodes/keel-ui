import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/repository/secrets_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class SecretsViewModel extends ViewModel<SecretsState> {
  SecretsViewModel() : super(const SecretsState());

  SecretsRepository get _repository => SecretsRepository();

  /// Same memoized-ready pattern as the other catalogs — a `request_secret`
  /// arriving right after startup must check the real persisted list.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedSecrets();

  @override
  void init() {
    if (_ready == null) updateSilently(const SecretsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedSecrets() async {
    try {
      final secrets = await _repository.load();
      updateState(data.copyWith(secrets: secrets));
    } catch (error) {
      Log.e('Failed to load persisted secrets', error: error);
    }
  }

  /// Resolves [names] to their env-var map, SKIPPING pending secrets — a
  /// missing value is never injected as an empty string, so a script can
  /// tell "not configured" apart from "configured empty".
  Map<String, String> valuesFor(List<String> names) {
    return {
      for (final secret in data.secrets)
        if (names.contains(secret.name) && !secret.isPending)
          secret.name: secret.value,
    };
  }

  /// Reads one configured value after the persisted catalog is ready.
  /// Callers receive only the requested value, never the vault collection.
  Future<String?> resolveValue(String? name) async {
    if (name == null) return null;
    await ready;
    return valuesFor([name])[name];
  }

  /// Names of the secrets in [names] that exist but still have no value.
  List<String> pendingOf(List<String> names) => [
    for (final secret in data.secrets)
      if (names.contains(secret.name) && secret.isPending) secret.name,
  ];

  /// Names in [names] with no secret registered under them at all — a
  /// dangling grant left by deleting a secret a tool or MCP still declares.
  /// Like a pending one it is skipped at injection time, but the fix is the
  /// opposite: drop the grant, or register the secret again.
  List<String> missingOf(List<String> names) {
    final registered = {for (final secret in data.secrets) secret.name};
    return names.where((name) => !registered.contains(name)).toList();
  }

  /// Registers a secret from the UI. Returns a user-facing error message on
  /// failure, or null on success.
  String? createSecret({
    required String name,
    required String description,
    required String value,
  }) {
    final error = _validateName(name);
    if (error != null) return error;

    final secret = Secret(
      id: generateUuidV4(),
      name: name,
      description: description.trim(),
      value: value,
      createdAt: DateTime.now(),
    );
    final secrets = [...data.secrets, secret];
    updateState(data.copyWith(secrets: secrets));
    unawaited(_repository.save(secrets));
    return null;
  }

  /// Creates a PENDING secret on an agent's behalf (no value — only the
  /// user can set one, from the Secrets screen). Idempotent by name.
  /// Returns a message describing what happened, for the agent's trace.
  String requestSecret({
    required String name,
    required String why,
    String? requestedByProfileId,
  }) {
    final formatError = validateSecretName(name);
    if (formatError != null) return formatError;

    final existing = data.secrets
        .where((secret) => secret.name == name)
        .firstOrNull;
    if (existing != null) {
      return existing.isPending
          ? 'El secret "$name" ya estaba pedido y sigue pendiente de valor.'
          : 'El secret "$name" ya existe y tiene valor configurado.';
    }

    final secret = Secret(
      id: generateUuidV4(),
      name: name,
      description: why.trim(),
      value: '',
      createdAt: DateTime.now(),
      requestedByProfileId: requestedByProfileId,
    );
    final secrets = [...data.secrets, secret];
    updateState(data.copyWith(secrets: secrets));
    unawaited(_repository.save(secrets));
    return 'Registré el secret "$name" como PENDIENTE — el usuario debe '
        'cargar el valor desde la pantalla de Secrets.';
  }

  /// Updates a secret from the UI. An empty [value] keeps the stored one
  /// (so editing the description never forces retyping the credential);
  /// use the explicit clear flow (delete + recreate) to blank a value.
  String? updateSecret(
    String id, {
    required String name,
    required String description,
    required String value,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final secrets = data.secrets
        .map(
          (secret) => secret.id == id
              ? secret.copyWith(
                  name: name,
                  description: description.trim(),
                  value: value.isEmpty ? null : value,
                )
              : secret,
        )
        .toList();
    updateState(data.copyWith(secrets: secrets));
    unawaited(_repository.save(secrets));
    return null;
  }

  void deleteSecret(String id) {
    final secrets = data.secrets.where((secret) => secret.id != id).toList();
    updateState(data.copyWith(secrets: secrets));
    unawaited(_repository.save(secrets));
  }

  String? _validateName(String name, {String? excludingId}) {
    final formatError = validateSecretName(name);
    if (formatError != null) return formatError;

    final isTaken = data.secrets.any(
      (secret) => secret.name == name && secret.id != excludingId,
    );
    if (isTaken) return 'Ya existe un secret con ese nombre.';
    return null;
  }
}

mixin SecretsService {
  static final ReactiveNotifier<SecretsViewModel> instance =
      ReactiveNotifier<SecretsViewModel>(() => SecretsViewModel());
}
