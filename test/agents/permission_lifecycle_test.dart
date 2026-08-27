import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  /// El `init` del ViewModel carga los agentes guardados y pisa el estado
  /// cuando llega. Con la base marcada como no disponible llega vacío, pero
  /// llega DESPUÉS: sin esperarlo, esa respuesta borra lo que sembró el test.
  Future<({AgentsViewModel viewModel, String agentId})> unAgente() async {
    final viewModel = AgentsViewModel();
    await pumpEventQueue();
    viewModel.createAgent(
      'Agente',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    return (viewModel: viewModel, agentId: viewModel.data.agents.single.id);
  }

  Future<CatalogPermissionOutcome> pedir(
    AgentsViewModel viewModel,
    String agentId,
  ) => viewModel.requestCatalogChangePermission(
    agentId: agentId,
    kind: 'skill',
    name: 'flutter-local-db',
    intent: 'Cambiar una línea del §7',
    reason: 'El puntero cruzado quedó muerto tras el rename',
  );

  test('mientras nadie contesta, la tarjeta queda en pantalla', () async {
    final (:viewModel, :agentId) = await unAgente();

    CatalogPermissionOutcome? resolved;
    unawaited(pedir(viewModel, agentId).then((value) => resolved = value));

    expect(viewModel.data.agents.single.pendingPermission, isNotNull);
    expect(resolved, isNull);
  });

  test('NO caduca sola por más tiempo que pase', () {
    // El caso que rompía el flujo: te demorabas y el pedido se moría solo.
    // Un permiso no tiene reloj — lo terminan una respuesta o un turno que
    // se detiene, y nada más.
    fakeAsync((async) {
      final viewModel = AgentsViewModel();
      async.flushMicrotasks();
      viewModel.createAgent(
        'Agente',
        model: kDefaultClaudeModelAlias,
        fullFileSystemAccess: false,
        effort: 'medium',
      );
      final agentId = viewModel.data.agents.single.id;

      CatalogPermissionOutcome? resolved;
      unawaited(pedir(viewModel, agentId).then((value) => resolved = value));
      async.flushMicrotasks();

      async.elapse(const Duration(hours: 3));

      expect(resolved, isNull);
      expect(viewModel.data.agents.single.pendingPermission, isNotNull);
    });
  });

  test('aprobar lo resuelve y limpia la tarjeta', () async {
    final (:viewModel, :agentId) = await unAgente();
    final pending = pedir(viewModel, agentId);

    viewModel.respondToPermissionRequest(agentId, grant: true);

    expect(await pending, CatalogPermissionOutcome.approved);
    expect(viewModel.data.agents.single.pendingPermission, isNull);
  });

  test('rechazar dice que fue un rechazo, no un vencimiento', () async {
    final (:viewModel, :agentId) = await unAgente();
    final pending = pedir(viewModel, agentId);

    viewModel.respondToPermissionRequest(agentId, grant: false);

    expect(await pending, CatalogPermissionOutcome.denied);
    expect(viewModel.data.agents.single.pendingPermission, isNull);
  });

  test('un segundo pedido dice que hay uno esperando', () async {
    final (:viewModel, :agentId) = await unAgente();
    final primero = pedir(viewModel, agentId);

    // Antes esto devolvía «rechazado» sin que nadie lo mirara, y el agente
    // dejaba de insistir por una negativa que nunca existió.
    expect(await pedir(viewModel, agentId), CatalogPermissionOutcome.busy);

    viewModel.respondToPermissionRequest(agentId, grant: true);
    expect(await primero, CatalogPermissionOutcome.approved);
  });

  test('un agente que no existe no deja a nadie esperando', () async {
    final (:viewModel, :agentId) = await unAgente();
    expect(agentId, isNotEmpty);

    expect(
      await pedir(viewModel, 'fantasma'),
      CatalogPermissionOutcome.cancelled,
    );
  });

  test('contestar dos veces no rompe nada', () async {
    final (:viewModel, :agentId) = await unAgente();
    final pending = pedir(viewModel, agentId);

    viewModel.respondToPermissionRequest(agentId, grant: true);
    viewModel.respondToPermissionRequest(agentId, grant: false);

    expect(await pending, CatalogPermissionOutcome.approved);
  });

  test('resuelto uno, se puede volver a pedir', () async {
    final (:viewModel, :agentId) = await unAgente();
    final primero = pedir(viewModel, agentId);
    viewModel.respondToPermissionRequest(agentId, grant: false);
    await primero;

    final segundo = pedir(viewModel, agentId);
    viewModel.respondToPermissionRequest(agentId, grant: true);

    expect(await segundo, CatalogPermissionOutcome.approved);
  });
}

/// `unawaited` sin arrastrar `dart:async` entero a un test.
void unawaited(Future<void> future) {}
