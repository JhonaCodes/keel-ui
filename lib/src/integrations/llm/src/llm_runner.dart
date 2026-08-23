part of '../llm.dart';

/// Un mensaje de turno ya normalizado — la misma forma de `Map` que hoy
/// cruza el isolate y que `TaskEvent.fromMessage` parsea. No es una clase
/// nueva a propósito: esa normalización ya existe y duplicarla en una
/// segunda jerarquía sería mantener el mismo contrato dos veces.
typedef LlmEvent = Map<String, dynamic>;

/// Lo que cualquier proveedor/target implementa para correr un turno. Un
/// runner CLI y uno de API se ven exactamente iguales desde acá: quien
/// llama a [run] no sabe si adentro hay un `Process` o un request HTTP.
abstract interface class LlmRunner {
  /// Emite los eventos del turno hasta que termina o [cancel] emite. Un
  /// runner CLI mata su proceso al recibir esa señal; uno de API aborta su
  /// request. [onPidKnown] solo lo llaman los runners que corren un
  /// [Process] real — sirve para poder mirarlo desde afuera con `ps`; un
  /// runner de API nunca lo invoca.
  Stream<LlmEvent> run(
    LlmTurnSpec spec, {
    required String userPath,
    required Stream<void> cancel,
    void Function(int pid)? onPidKnown,
  });
}
