import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:keel_ui/src/core/services/agent_bridge_channel.dart';
import 'package:keel_ui/src/core/services/app_window_arguments.dart';
import 'package:keel_ui/src/core/services/legacy_json_migration.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/services/main_window_size.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/jobs_api/jobs_api.dart';
import 'package:keel_ui/src/integrations/task_plan_mcp/task_plan_mcp_server.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/file_editor_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/agents_screen.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/file_editor_window.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_arguments.dart';
import 'package:keel_ui/src/modules/assistant/model/keelai_seed.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';
import 'package:keel_ui/src/modules/assistant/ui/screen/assistant_window.dart';

Future<void> main(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  final json = AppWindowArguments.decode(windowController.arguments);
  final businessId =
      json?['businessId'] as String? ?? AppWindowArguments.idMain;

  switch (businessId) {
    case FileEditorWindowArguments.id:
      LocalDatabase.markUnavailable();
      runApp(
        FileEditorWindow(arguments: FileEditorWindowArguments.fromJson(json!)),
      );
      _showWhenPainted(windowController);

    case AssistantWindowArguments.id:
      // Sin base en este engine, y dicho explícitamente: los ViewModels que
      // toque esta ventana (el de settings, vía el font scale de las
      // burbujas) tienen que leer "no hay nada guardado", no reventar.
      LocalDatabase.markUnavailable();
      runApp(const AssistantWindow());
      _showWhenPainted(windowController);

    // Sub-windows (e.g. the file editor) add their own case here, using
    // AppWindowArguments as the JSON contract and window_manager to size
    // and show themselves — see openAppWindow in app_window_service.dart.
    // They deliberately get NO database, NO seed, and NO MCP servers: each
    // sub-window is another Flutter engine, and duplicating that init gave
    // every window its own LMDB handle and two extra HTTP servers backed by
    // empty ViewModels.
    case AppWindowArguments.idMain:
    default:
      await LocalDatabase.ensureInitialized();
      await migrateLegacyJsonIfNeeded();
      // Después de la base (lee el tamaño guardado) y antes de runApp: la
      // ventana nativa abre con el tamaño del xib, que es demasiado chico
      // para las tres columnas.
      await MainWindowSize.restore();
      await seedKeelAi();
      await AssistantMcpServer.start();
      await UserToolsMcpServer.start();
      await TaskPlanMcpServer.ensureStarted();
      await JobsApiService.instance.notifier.start();
      _registerAgentBridgeHandler();
      runApp(const KeelUiApp());
  }
}

/// Muestra esta sub-ventana recién cuando su engine pintó un frame.
///
/// Las sub-ventanas se crean ocultas (`hiddenAtLaunch`) justamente para
/// esto: si la ventana aparece mientras el engine todavía arranca, lo que
/// se ve es una superficie sin nada, o sea un rectángulo negro. El engine
/// que la va a llenar es el único que sabe cuándo está listo.
void _showWhenPainted(WindowController controller) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(controller.show());
  });
}

void _registerAgentBridgeHandler() {
  agentBridgeChannel.setMethodCallHandler((call) async {
    // The assistant window speaks its own sub-protocol: one String JSON
    // payload per call, answered (sometimes) with a String JSON state.
    if (call.method.startsWith('assistant.')) {
      return AssistantWindowBridge.instance.handleCall(
        call.method.substring('assistant.'.length),
        call.arguments as String? ?? '',
      );
    }

    final args = (call.arguments as Map).cast<String, dynamic>();

    switch (call.method) {
      case 'askAboutLine':
        await AgentsService.instance.notifier.askAboutLine(
          args['agentId'] as String,
          filePath: args['filePath'] as String,
          lineNumber: args['lineNumber'] as int,
          lineContent: args['lineContent'] as String,
          question: args['question'] as String,
        );
      case 'recordManualEdit':
        AgentsService.instance.notifier.recordManualEdit(
          args['agentId'] as String,
          FileEdit(
            path: args['filePath'] as String,
            beforeContent: args['beforeContent'] as String,
            afterContent: args['afterContent'] as String,
          ),
        );
    }
    return null;
  });
}

class KeelUiApp extends StatelessWidget {
  const KeelUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keel UI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AgentsScreen(),
    );
  }
}
