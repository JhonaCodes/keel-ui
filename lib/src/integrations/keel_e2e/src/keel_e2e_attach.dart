part of '../keel_e2e.dart';

/// Por qué [ensureKeelE2eAttached] no pudo devolver una [EngineConnection].
///
/// Dos causas bien distintas (architecture §5, §9): el binario no se
/// encontró —nunca se llegó a arrancar nada— o el proceso arrancó y nunca
/// imprimió `KEEL_E2E_READY` (el `HostFailed` que el panel ya sabe mostrar
/// como "motor detenido"). El llamador decide qué hacer con cada una: la
/// pestaña E2E localiza el primer caso con su propio texto y deja que el
/// panel muestre el segundo por sí solo; el turno de un paso keel-e2e
/// muestra [message] tal cual en el canal para los dos, porque ahí no hay
/// panel observando todavía.
sealed class KeelE2eAttachFailure {
  const KeelE2eAttachFailure();

  /// El motivo en español neutro, listo para un mensaje de sistema del
  /// canal.
  String get message;
}

/// This build of Keel carries no embedded engine ([KeelE2eBinary]), so
/// [KeelE2eHostViewModel.attach] was never called.
final class KeelE2eBinaryMissing extends KeelE2eAttachFailure {
  const KeelE2eBinaryMissing();

  @override
  String get message =>
      'Esta compilación de Keel no incluye el motor keel-e2e. Vuelve a '
      'compilar Keel para incluirlo.';
}

/// El proceso arrancó pero nunca imprimió `KEEL_E2E_READY` (timeout, crash,
/// binario inválido) — el mismo [reason] de un `HostFailed`.
final class KeelE2eEngineFailed extends KeelE2eAttachFailure {
  const KeelE2eEngineFailed(this.reason);

  final String reason;

  @override
  String get message => reason;
}

/// Punto de entrada único para dejar el engine de keel-e2e arrancado y
/// apuntando a esta sesión (architecture §5, §14 "Supervisor host"):
/// resuelve el binario, resuelve el `dataDir` y llama
/// `KeelE2eHostService.instance.notifier.attach(...)`. Lo usan la pestaña
/// E2E (`SessionE2eView`, que solo dispara y renderiza) y el turno de un
/// paso que declaró keel-e2e (`ProjectsViewModel._runTurn`, que aborta el
/// turno si esto falla) — ninguno de los dos vuelve a resolver una ruta de
/// binario por su cuenta.
///
/// Llamarlo de nuevo para la misma sesión no repite el arranque: `attach`
/// ya es idempotente por (binario, dataDir) y solo reapunta la sesión que
/// observa el control client (architecture §6.1, "un engine por máquina").
/// [debugEngineBinaryOverride] no lleva `@visibleForTesting`: lo reenvía
/// `SessionE2eView` desde su propio parámetro —ese sí restringido a tests—
/// y una anotación acá lo marcaría como mal uso justo en ese llamador de
/// producción.
Future<Result<EngineConnection, KeelE2eAttachFailure>> ensureKeelE2eAttached({
  required Project project,
  required String sessionId,
  String? debugEngineBinaryOverride,
}) async {
  final binary = debugEngineBinaryOverride ?? KeelE2eBinary.embedded();
  if (binary == null) return Err(const KeelE2eBinaryMissing());

  final dataDir = await keelE2eDataDir();
  final result = await KeelE2eHostService.instance.notifier.attach(
    KeelE2eHostConfig(
      engineBinary: binary,
      dataDir: dataDir,
      projectRoot: project.workingDirectory,
      sessionId: sessionId,
    ),
  );
  return result.when(
    ok: (connection) => Ok<EngineConnection, KeelE2eAttachFailure>(connection),
    err: (failure) => Err<EngineConnection, KeelE2eAttachFailure>(
      KeelE2eEngineFailed(failure.message),
    ),
  );
}

/// Hands `KeelE2eHostViewModel` the host's config without starting the
/// engine (architecture §9's "Iniciar motor" on the engine-stopped card):
/// `SessionE2eView` calls this on mount when there is no session yet, so
/// the button has something to start from. Resolves the same binary and
/// `dataDir` [ensureKeelE2eAttached] does — never a second resolution
/// policy — but never spawns a process on its own.
Future<Result<void, KeelE2eAttachFailure>> prepareKeelE2eHost({
  required Project project,
  required String sessionId,
  String? debugEngineBinaryOverride,
}) async {
  final binary = debugEngineBinaryOverride ?? KeelE2eBinary.embedded();
  if (binary == null) return Err(const KeelE2eBinaryMissing());

  final dataDir = await keelE2eDataDir();
  KeelE2eHostService.instance.notifier.prepare(
    KeelE2eHostConfig(
      engineBinary: binary,
      dataDir: dataDir,
      projectRoot: project.workingDirectory,
      sessionId: sessionId,
    ),
  );
  return Ok(null);
}
