import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keel_e2e_panel/keel_e2e_panel.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/integrations/keel_e2e/keel_e2e.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_tab.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

/// Thin host for the keel-e2e panel on the E2E tab (architecture §14).
///
/// Dispara `ensureKeelE2eAttached` con el proyecto y la sesión, y muestra
/// `const KeelE2ePanel()` — el panel mismo renderiza todo estado del engine,
/// incluido "motor detenido" a partir de un `HostFailed`
/// (`KeelE2ePanel` lee `KeelE2eHostService` por su cuenta). Esta vista solo
/// dispara el intento de attach y renderiza el único caso que el panel no
/// puede mostrar —el binario ni siquiera se encontró, así que nunca hubo
/// proceso que arrancar—; no resuelve rutas de binario ni `dataDir` por su
/// cuenta, eso vive en `ensureKeelE2eAttached`.
class SessionE2eView extends StatefulWidget {
  const SessionE2eView({
    super.key,
    required this.project,
    this.session,
    @visibleForTesting this.debugEngineBinaryOverride,
  });

  final Project project;
  final Session? session;

  /// A fixed engine binary path, skipping [KeelE2eBinary.embedded] — for
  /// widget tests that need a deterministic, never-really-executed
  /// "binary" (e.g. a non-executable fixture that makes `Process.start`
  /// fail fast, instead of racing the real engine or the 30 s ready
  /// timeout).
  @visibleForTesting
  final String? debugEngineBinaryOverride;

  @override
  State<SessionE2eView> createState() => _SessionE2eViewState();
}

class _SessionE2eViewState extends State<SessionE2eView> {
  /// The (projectId, sessionId) pair already attached for, so switching back
  /// to this tab without a session change does not re-attach.
  ({String projectId, String sessionId})? _attachedFor;

  /// `null` while resolution hasn't run yet; `''` means "looked and found
  /// nothing".
  String? _missingBinaryReason;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureAttached();
  }

  @override
  void didUpdateWidget(covariant SessionE2eView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureAttached();
  }

  void _ensureAttached() {
    final session = widget.session;
    // Sin sesión todavía (architecture §9's "Iniciar motor" en la tarjeta
    // de motor apagado): el host recibe su config igual, con un id de
    // sesión vacío que `KeelE2eHostViewModel` trata como "sin stream" —
    // nunca arranca el proceso por su cuenta, solo lo deja listo para que
    // el botón lo haga.
    final key = (projectId: widget.project.id, sessionId: session?.id ?? '');
    if (_attachedFor == key) return;
    _attachedFor = key;
    setState(() => _missingBinaryReason = null);

    void handleResult(Result<Object?, KeelE2eAttachFailure> result) {
      if (!mounted || _attachedFor != key) return;
      // El panel ya observa `KeelE2eHostService` y muestra por su cuenta
      // cualquier `HostFailed` del proceso: esta vista solo tiene que
      // decir algo cuando el binario ni siquiera se encontró, el único
      // caso en el que nunca hubo proceso ni estado que el panel pudiera
      // leer.
      if (result case Err(error: KeelE2eBinaryMissing())) {
        setState(() {
          _missingBinaryReason = AppLocalizations.of(
            context,
          ).e2eEngineBinaryMissing;
        });
      }
    }

    if (session == null) {
      unawaited(
        prepareKeelE2eHost(
          project: widget.project,
          sessionId: '',
          debugEngineBinaryOverride: widget.debugEngineBinaryOverride,
        ).then(handleResult),
      );
    } else {
      unawaited(
        ensureKeelE2eAttached(
          project: widget.project,
          sessionId: session.id,
          debugEngineBinaryOverride: widget.debugEngineBinaryOverride,
        ).then(handleResult),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _missingBinaryReason;
    if (reason != null) return _MissingBinaryMessage(reason: reason);
    // "Responder en Chat" (la tarjeta de permiso pendiente): esta vista es
    // la única que sabe que su propio canal tiene una pestaña Chat a la
    // que volver — el panel no conoce `SessionTab`.
    return KeelE2ePanel(
      onOpenChat: () => ProjectsService.instance.notifier.setTab(
        widget.project.id,
        SessionTab.chat,
      ),
    );
  }
}

class _MissingBinaryMessage extends StatelessWidget {
  const _MissingBinaryMessage({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phonelink_off_outlined, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              reason,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
