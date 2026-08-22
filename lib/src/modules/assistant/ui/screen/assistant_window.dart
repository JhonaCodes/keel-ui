import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/ui/view/chat_view.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_state.dart';
import 'package:keel_ui/src/modules/assistant/service/bridge_chat_actions.dart';
import 'package:keel_ui/src/modules/assistant/ui/widget/assistant_welcome_card.dart';
import 'package:keel_ui/src/modules/assistant/viewmodel/assistant_window_viewmodel.dart';

/// Root widget of the dedicated Keel AI window — a presentation client of
/// the MAIN engine. Everything it shows arrives as pushed snapshots via
/// [AssistantWindowViewModel]; everything the user does travels back over
/// the bridge ([BridgeChatActions] / the session intents).
class AssistantWindow extends StatefulWidget {
  const AssistantWindow({super.key});

  @override
  State<AssistantWindow> createState() => _AssistantWindowState();
}

class _AssistantWindowState extends State<AssistantWindow> {
  final _composer = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_configureWindow());
  }

  Future<void> _configureWindow() async {
    const options = WindowOptions(
      size: Size(720, 800),
      minimumSize: Size(520, 560),
      center: true,
      title: 'Asistente',
      titleBarStyle: TitleBarStyle.normal,
      // Sin esto, cualquier hueco antes del primer raster es el
      // `FlutterView` vacío, que se ve negro. Con esto es el fondo de
      // la app, y el hueco deja de notarse aunque exista.
      backgroundColor: AppColors.bg,
    );
    // Configurar y NADA MÁS. Mostrar desde acá era el rectángulo negro: esto
    // corre en `initState`, cuando todavía no existe ningún frame, y encima
    // `waitUntilReadyToShow` redimensiona y centra DESPUÉS de mostrar, así
    // que el área nueva quedaba sin pintar. Quien muestra es
    // `_showWhenPainted`, que para eso espera al primer frame.
    await windowManager.waitUntilReadyToShow(options);
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistente',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home:
          ReactiveViewModelBuilder<
            AssistantWindowViewModel,
            AssistantWindowState
          >(
            viewmodel: AssistantWindowClientService.instance.notifier,
            build: (state, viewmodel, keep) {
              final snapshot = state.agent;
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Asistente'),
                  actions: [
                    if (state.sessions.length > 1)
                      _SessionsMenu(
                        sessions: state.sessions,
                        selectedId: state.activeAgentId,
                        onSelect: (id) =>
                            unawaited(viewmodel.selectSession(id)),
                      ),
                    IconButton(
                      tooltip: 'Nueva conversación',
                      icon: const Icon(Icons.add_comment_outlined),
                      onPressed: () => unawaited(viewmodel.newSession()),
                    ),
                  ],
                ),
                body: snapshot == null
                    ? const Center(child: CircularProgressIndicator())
                    : ChatView(
                        key: ValueKey(snapshot.id),
                        agent: snapshot.toAgent(),
                        controller: _composer,
                        actions: const BridgeChatActions(),
                        fontScaleOverride: state.chatFontScale,
                        emptyState: AssistantWelcomeCard(
                          onExampleTap: (prompt) =>
                              setState(() => _composer.text = prompt),
                        ),
                      ),
              );
            },
          ),
    );
  }
}

class _SessionsMenu extends StatelessWidget {
  const _SessionsMenu({
    required this.sessions,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AssistantSessionSummary> sessions;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Conversaciones',
      icon: const Icon(Icons.history),
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final session in sessions)
          CheckedPopupMenuItem(
            value: session.id,
            checked: session.id == selectedId,
            child: Text(session.label),
          ),
      ],
    );
  }
}
