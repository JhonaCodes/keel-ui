import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/plan_decision.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  group('cuándo se pregunta si implementar', () {
    test('el turno planificó y llegó al final solo', () {
      expect(
        shouldAskToImplement(
          planMode: true,
          stopped: false,
          hasAnswer: true,
          hasQueuedMessages: false,
        ),
        isTrue,
      );
    });

    test('un turno normal no pregunta nunca', () {
      expect(
        shouldAskToImplement(
          planMode: false,
          stopped: false,
          hasAnswer: true,
          hasQueuedMessages: false,
        ),
        isFalse,
      );
    });

    test('frenarlo a mano es tomar el control, no pedir permiso', () {
      expect(
        shouldAskToImplement(
          planMode: true,
          stopped: true,
          hasAnswer: true,
          hasQueuedMessages: false,
        ),
        isFalse,
      );
    });

    test('sin respuesta no hay plan que aprobar', () {
      expect(
        shouldAskToImplement(
          planMode: true,
          stopped: false,
          hasAnswer: false,
          hasQueuedMessages: false,
        ),
        isFalse,
      );
    });

    test('si escribiste mientras planificaba, ya decidiste vos', () {
      // Y encima ese mensaje sale como turno nuevo en un instante: la
      // tarjeta quedaría flotando sobre un agente que ya está en otra cosa.
      expect(
        shouldAskToImplement(
          planMode: true,
          stopped: false,
          hasAnswer: true,
          hasQueuedMessages: true,
        ),
        isFalse,
      );
    });
  });

  group('el pedido de implementar', () {
    test('lleva el plan escrito adentro', () {
      // No alcanza con confiar en el `--resume`: si la sesión del CLI murió
      // y hay que reintentar sin ella, un agente que lee «implementá lo
      // acordado» sin saber qué se acordó implementa cualquier cosa.
      final pedido = planApprovalRequest(
        'Renombrar `foo` a `bar` en tres archivos.',
      );

      expect(pedido, contains('Renombrar `foo` a `bar`'));
      expect(pedido, contains('Aprobé el plan'));
    });

    test('sin plan a mano, sigue siendo una orden legible', () {
      for (final vacio in [null, '', '   ']) {
        final pedido = planApprovalRequest(vacio);

        expect(pedido, contains('Aprobé el plan'));
        expect(pedido.contains('para que no dependa de la sesión'), isFalse);
      }
    });

    test('no pide rediseñar: el plan ya se acordó', () {
      expect(planApprovalRequest('algo'), contains('no lo vuelvas a proponer'));
    });
  });

  group('el toggle del agente', () {
    /// El `init` del ViewModel carga los agentes guardados y pisa el estado
    /// cuando llega: hay que esperarlo antes de sembrar nada.
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

    test('arranca apagado', () async {
      final (:viewModel, agentId: _) = await unAgente();

      expect(viewModel.data.agents.single.planMode, isFalse);
    });

    test('se prende y se apaga', () async {
      final (:viewModel, :agentId) = await unAgente();

      viewModel.setAgentPlanMode(agentId, true);
      expect(viewModel.data.agents.single.planMode, isTrue);

      viewModel.setAgentPlanMode(agentId, false);
      expect(viewModel.data.agents.single.planMode, isFalse);
    });

    test('sin tarjeta pendiente, implementar no manda nada', () async {
      final (:viewModel, :agentId) = await unAgente();
      viewModel.setAgentPlanMode(agentId, true);

      viewModel.implementPlan(agentId);
      await pumpEventQueue();

      expect(viewModel.data.agents.single.planMode, isTrue);
      expect(viewModel.data.agents.single.messages, isEmpty);
    });
  });

  group('qué se guarda y qué no', () {
    test('el modo sobrevive, la tarjeta no', () {
      // El modo es una decisión del usuario sobre la conversación; la
      // tarjeta es una pregunta en pantalla. Nadie quiere reabrir la app y
      // encontrar una pregunta de hace tres días sobre un plan que ya no
      // recuerda.
      final agent = Agent(
        id: 'a',
        name: 'Agente',
        model: 'sonnet',
        createdAt: DateTime.utc(2026, 8, 27),
        iconColor: kAgentIconColorPalette.first,
        effort: 'medium',
        planMode: true,
        planAwaitingDecision: true,
      );

      final ida = Agent.fromJson(agent.toJson());

      expect(ida.planMode, isTrue);
      expect(ida.planAwaitingDecision, isFalse);
    });

    test('un agente guardado antes de que esto existiera se lee apagado', () {
      final agent = Agent.fromJson({
        'id': 'a',
        'name': 'Agente',
        'model': 'sonnet',
        'createdAt': DateTime.utc(2026, 8, 27).toIso8601String(),
        'effort': 'medium',
        'messages': const [],
      });

      expect(agent.planMode, isFalse);
    });
  });

  test('no pregunta si el turno cerró preguntándole al usuario', () {
    // El banner «¿implementamos?» saltaba aunque el agente solo hubiera
    // hecho una pregunta: dos tarjetas para una sola cosa que decidir.
    expect(
      shouldAskToImplement(
        planMode: true,
        stopped: false,
        hasAnswer: true,
        hasQueuedMessages: false,
        askedUser: true,
      ),
      isFalse,
    );
  });

}
