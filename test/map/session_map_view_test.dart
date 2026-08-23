import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_map_view.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_legend.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_node_card.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

final _epoch = DateTime(2026, 8, 23);

AgentProfile _member(String name) => AgentProfile(
  id: name,
  name: name,
  role: name,
  systemPrompt: '',
  model: 'sonnet',
  effort: 'normal',
  createdAt: _epoch,
);

/// El workflow real del usuario: ocho pasos y el mismo miembro repetido.
final _tdd = Workflow(
  id: 'wf',
  name: 'tdd',
  whenToApply: '',
  createdAt: _epoch,
  steps: [
    for (final (title, role) in [
      ('Charter', 'planificador'),
      ('RED causal', 'flutter-expert'),
      ('GREEN mínimo', 'flutter-expert'),
      ('Prueba de relevancia', 'auditor-tests'),
      ('Refactor', 'flutter-expert'),
      ('Verificación', 'verificador'),
      ('Compuerta', 'auditor'),
      ('Entrega', 'flutter-expert'),
    ])
      WorkflowStep(
        id: title,
        title: title,
        role: role,
        instruction: 'La instrucción de $title.',
      ),
  ],
);

final _cast = [
  _member('planificador'),
  _member('flutter-expert'),
  _member('auditor-tests'),
  _member('verificador'),
  _member('auditor'),
];

Widget _app({Session? session, Size size = const Size(1100, 700)}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: SessionMapView(
            project: Project(
              id: 'p',
              name: 'aulamas-portal',
              purpose: '',
              workingDirectory: '/tmp',
              createdAt: _epoch,
            ),
            session: session,
            members: _cast,
            workflow: _tdd,
          ),
        ),
      ),
    ),
  );
}

Session _session({
  List<ChatMessage> messages = const [],
  List<SessionSubagent> subagents = const [],
  SessionLiveTurn? liveTurn,
  bool isRunning = false,
  int currentStepIndex = 0,
}) => Session(
  id: 's1',
  title: 'sesión',
  createdAt: _epoch,
  messages: messages,
  subagents: subagents,
  liveTurn: liveTurn,
  isRunning: isRunning,
  currentStepIndex: currentStepIndex,
);

void main() {
  group('el lienzo se dibuja entero y sin desbordes', () {
    testWidgets('en reposo, con los ocho pasos puestos', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.byType(MapNodeCard), findsNWidgets(10)); // vos + 8 + fin
      expect(find.text('planificador'), findsOneWidget);
      expect(find.text('flutter-expert'), findsNWidgets(4));
      expect(find.text('vos'), findsOneWidget);
      expect(find.text('fin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con un turno vivo y dos subagentes', (tester) async {
      await tester.pumpWidget(
        _app(
          session: _session(
            isRunning: true,
            currentStepIndex: 1,
            messages: [
              ChatMessage(
                role: ChatRole.assistant,
                text: 'El charter quedó cerrado. Vamos al rojo.',
                timestamp: _epoch,
                authorProfileId: 'planificador',
                stepIndex: 0,
                durationMs: 12000,
              ),
            ],
            liveTurn: const SessionLiveTurn(
              profileId: 'flutter-expert',
              phase: TurnPhase.working,
              activity: AgentToolActivity(
                kind: AgentToolKind.bash,
                label: 'Ejecutando: flutter test test/bid',
              ),
            ),
            subagents: [
              SessionSubagent(
                id: 't1',
                parentProfileId: 'flutter-expert',
                parentStepIndex: 1,
                agentType: 'Explore',
                ask: 'Dónde se resuelve el precio',
                prompt: 'Encontrá dónde se resuelve el precio final del lote.',
                startedAt: _epoch,
                reasoning: 'Hay dos rutas y conviene descartar una.',
              ),
              SessionSubagent(
                id: 't2',
                parentProfileId: 'flutter-expert',
                parentStepIndex: 1,
                agentType: 'Plan',
                ask: 'Armá el plan',
                prompt: 'Armá un plan de cuatro pasos.',
                startedAt: _epoch,
                finishedAt: _epoch,
                phase: SubagentPhase.done,
                result: 'Cuatro pasos; el segundo toca bid_view_model.',
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('El charter quedó cerrado.'), findsOneWidget);
      expect(
        find.text('Cuatro pasos; el segundo toca bid_view_model.'),
        findsOneWidget,
      );
      // El indicador animado del chat, reusado tal cual dentro del nodo.
      expect(find.text('Ejecutando: flutter test test/bid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en un panel angosto tampoco desborda', (tester) async {
      await tester.pumpWidget(_app(size: const Size(520, 420)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('la barra', () {
    testWidgets('el zoom cambia y se muestra', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.zoom_in));
      await tester.pump();
      expect(find.text('125%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.zoom_out));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('encuadrar mete el lienzo entero en pantalla', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('Encuadrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Ocho pasos no entran a tamaño real en 1100 px: encuadrar aleja.
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('la leyenda se abre y se cierra', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.byType(MapLegend), findsNothing);

      await tester.tap(find.text('Leyenda'));
      await tester.pump();
      expect(find.byType(MapLegend), findsOneWidget);
      expect(find.text('consulta a otro nodo'), findsOneWidget);

      await tester.tap(find.text('Leyenda'));
      await tester.pump();
      expect(find.byType(MapLegend), findsNothing);
    });
  });

  group('entrar a un nodo', () {
    testWidgets('abre el inspector con lo que se le pidió', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('planificador'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('EL ENCARGO'), findsOneWidget);
      expect(find.text('La instrucción de Charter.'), findsOneWidget);
      expect(find.text('paso 1 · Charter'), findsOneWidget);
      expect(find.text('Escribile a @planificador…'), findsOneWidget);
    });

    testWidgets('un subagente en curso dice por qué no se le escribe', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          session: _session(
            subagents: [
              SessionSubagent(
                id: 't1',
                parentProfileId: 'flutter-expert',
                parentStepIndex: 1,
                agentType: 'Explore',
                ask: 'Dónde se resuelve el precio',
                prompt: 'Encontrá dónde se resuelve el precio final del lote.',
                startedAt: _epoch,
                reasoning: 'Hay dos rutas.',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Explore'));
      // Con un subagente corriendo hay un halo latiendo: pumpAndSettle nunca
      // se asienta, y eso es correcto —el mapa está vivo.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Encontrá dónde se resuelve el precio final del lote.'),
        findsOneWidget,
      );
      expect(find.textContaining('no se le puede escribir'), findsOneWidget);
      expect(find.text('al padre'), findsOneWidget);
      expect(find.text('Escribile a @flutter-expert…'), findsOneWidget);
    });
  });
}
