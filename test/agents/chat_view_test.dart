import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/agents/service/chat_actions.dart';
import 'package:keel_ui/src/modules/agents/ui/view/chat_view.dart';

final _epoch = DateTime(2026, 8, 24);

void main() {
  group('el pedido de permiso', _permissionTests);

  testWidgets(
    'elegir Codex actualiza el proveedor y muestra su modelo por defecto',
    (tester) async {
      late _RecordingChatActions actions;
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                child: _ChatHarness(onActionsReady: (value) => actions = value),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('provider-claude')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();

      expect(actions.providerChanges, [
        ('keelai-session', AgentProvider.codex),
      ]);
      expect(find.byKey(const ValueKey('model-codex')), findsOneWidget);
      expect(find.text('El de tu config de codex'), findsOneWidget);
    },
  );

  testWidgets('OpenRouter y DeepSeek aparecen como proveedores del chat', (
    tester,
  ) async {
    late _RecordingChatActions actions;
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: _ChatHarness(onActionsReady: (value) => actions = value),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('provider-claude')));
    await tester.pumpAndSettle();
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);

    await tester.tap(find.text('OpenRouter'));
    await tester.pumpAndSettle();
    expect(actions.providerChanges, [
      ('keelai-session', AgentProvider.openRouter),
    ]);
    expect(find.byKey(const ValueKey('model-openrouter')), findsOneWidget);
  });
}

/// Un pedido de cambio de catálogo: la variante ALTA, que es la que no
/// entraba en el recorte de 160 px que tenía este chat.
final _catalogRequest = const PermissionRequest(
  toolName: 'create_rule',
  message: 'Keel AI quiere cambiar una regla bloqueada',
  kind: 'rule',
  itemName: 'tdd-obligatorio',
  changeIntent: 'update',
  changeReason: 'El equipo dejó de usar el paso de revisión manual',
  requestedBy: 'keelai',
);

void _permissionTests() {
  Future<void> abrir(
    WidgetTester tester, {
    PermissionRequest? permiso,
    int mensajes = 12,
    bool trabajando = false,
    ValueChanged<_RecordingChatActions>? onActions,
  }) async {
    await tester.binding.setSurfaceSize(const Size(720, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ChatHarness(
            onActionsReady: onActions ?? (_) {},
            pendingPermission: permiso,
            isStreaming: trabajando,
            messages: [
              for (var i = 0; i < mensajes; i++)
                ChatMessage(
                  role: i.isEven ? ChatRole.user : ChatRole.assistant,
                  text: 'Mensaje número $i, largo como para llenar la ventana.',
                  timestamp: _epoch.add(Duration(minutes: i)),
                ),
            ],
          ),
        ),
      ),
    );
    // Con el agente trabajando hay una barra de progreso infinita: nunca
    // «settlea», así que se avanzan frames a mano.
    if (trabajando) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('el pedido se ve entero, con sus dos botones', (tester) async {
    await abrir(tester, permiso: _catalogRequest);

    expect(find.byType(PermissionRequestBanner), findsOneWidget);
    // Los botones son la parte que quedaba del otro lado del recorte.
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Aprobar cambio'), findsOneWidget);

    final tarjeta = tester.getRect(find.byType(PermissionRequestBanner));
    final ventana = tester.getRect(find.byType(Scaffold));
    expect(
      tarjeta.bottom,
      lessThanOrEqualTo(ventana.bottom),
      reason: 'la tarjeta no puede terminar fuera de la ventana',
    );
    expect(tarjeta.height, greaterThan(160));
  });

  testWidgets('flota SOBRE las burbujas, no atrás', (tester) async {
    await abrir(tester, permiso: _catalogRequest);

    // Se pinta después que el hilo: en un Stack, el último es el de arriba.
    final hilo = find.byType(ListView);
    expect(hilo, findsOneWidget);
    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(PermissionRequestBanner),
            matching: find.byType(Stack),
          )
          .first,
    );
    // El hilo va con `Positioned.fill` —que también deja `bottom: 0`—, así
    // que lo que distingue a la tarjeta es que NO está anclada arriba.
    final indiceTarjeta = stack.children.indexWhere(
      (child) => child is Positioned && child.top == null && child.bottom == 0,
    );
    expect(indiceTarjeta, stack.children.length - 1);
  });

  testWidgets('el hilo le reserva el lugar y no queda nada tapado', (
    tester,
  ) async {
    await abrir(tester, permiso: _catalogRequest);

    final tarjeta = tester.getRect(find.byType(PermissionRequestBanner));
    final lista = tester.widget<ListView>(find.byType(ListView));
    final reservado = lista.padding!.resolve(TextDirection.ltr).bottom;

    expect(
      reservado,
      greaterThanOrEqualTo(tarjeta.height),
      reason: 'la última burbuja no puede quedar debajo de la tarjeta',
    );
  });

  testWidgets('se puede contestar CON el agente trabajando', (tester) async {
    // El caso real: la tool está suspendida esperando la respuesta, así que
    // el turno figura corriendo justo mientras hay que contestar. Con los
    // botones atados a `isStreaming` no había forma de destrabarlo.
    await abrir(tester, permiso: _catalogRequest, trabajando: true);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Rechazar'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('contestada una vez, no se puede contestar dos', (tester) async {
    late _RecordingChatActions actions;
    await abrir(
      tester,
      permiso: _catalogRequest,
      trabajando: true,
      onActions: (value) => actions = value,
    );

    await tester.tap(find.text('Aprobar cambio'));
    await tester.pump();
    await tester.tap(find.text('Aprobar cambio'), warnIfMissed: false);
    await tester.pump();

    expect(actions.permissionAnswers, [true]);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('sin permiso pendiente no queda hueco abajo', (tester) async {
    await abrir(tester);

    final lista = tester.widget<ListView>(find.byType(ListView));
    expect(lista.padding!.resolve(TextDirection.ltr).bottom, 16);
    expect(find.byType(PermissionRequestBanner), findsNothing);
  });
}

class _ChatHarness extends StatefulWidget {
  const _ChatHarness({
    required this.onActionsReady,
    this.messages = const [],
    this.pendingPermission,
    this.isStreaming = false,
  });

  final ValueChanged<_RecordingChatActions> onActionsReady;
  final List<ChatMessage> messages;
  final PermissionRequest? pendingPermission;
  final bool isStreaming;

  @override
  State<_ChatHarness> createState() => _ChatHarnessState();
}

class _ChatHarnessState extends State<_ChatHarness> {
  late Agent _agent;
  late final _RecordingChatActions _actions;

  @override
  void initState() {
    super.initState();
    _agent = Agent(
      id: 'keelai-session',
      name: 'Keel AI',
      model: kDefaultClaudeModelAlias,
      provider: AgentProvider.claude,
      createdAt: _epoch,
      iconColor: Colors.deepPurple,
      effort: 'medium',
      messages: widget.messages,
      pendingPermission: widget.pendingPermission,
      isStreaming: widget.isStreaming,
    );
    _actions = _RecordingChatActions(
      onProviderChanged: (agentId, provider) {
        setState(() {
          _agent = _agent.copyWith(
            provider: provider,
            model: defaultModelFor(provider),
          );
        });
      },
    );
    widget.onActionsReady(_actions);
  }

  @override
  Widget build(BuildContext context) {
    return ChatView(agent: _agent, actions: _actions);
  }
}

class _RecordingChatActions extends LocalChatActions {
  _RecordingChatActions({required this.onProviderChanged});

  final void Function(String agentId, AgentProvider provider) onProviderChanged;
  final List<(String, AgentProvider)> providerChanges = [];
  final List<bool> permissionAnswers = [];

  /// Sin esto la respuesta cae en el ViewModel de verdad, que en un test no
  /// tiene a este agente registrado.
  @override
  void respondToPermissionRequest(String agentId, {required bool grant}) {
    permissionAnswers.add(grant);
  }

  @override
  void setAgentProvider(String agentId, AgentProvider provider) {
    providerChanges.add((agentId, provider));
    onProviderChanged(agentId, provider);
  }
}
