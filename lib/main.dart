import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:keel_ui/src/core/services/agent_bridge_channel.dart';
import 'package:keel_ui/src/core/services/app_window_arguments.dart';
import 'package:keel_ui/src/core/services/legacy_json_migration.dart';
import 'package:keel_ui/src/core/services/station_to_project_migration.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/services/main_window_size.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/jobs_api/jobs_api.dart';
import 'package:keel_ui/src/integrations/requirements_mcp/requirements_mcp.dart';
import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';
import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';
import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';
import 'package:keel_ui/src/integrations/session_plan_mcp/session_plan_mcp_server.dart';
import 'package:keel_ui/src/integrations/user_tools_mcp/user_tools_mcp_server.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/file_editor_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/agents_screen.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/file_editor_window.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/app_status/ui/widget/app_busy_overlay.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_arguments.dart';
import 'package:keel_ui/src/modules/assistant/model/keelai_seed.dart';
import 'package:keel_ui/src/modules/projects/model/roadmap_format_skill.dart';
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
      await migrateStationsToProjects();
      // Después de la base (lee el tamaño guardado) y antes de runApp: la
      // ventana nativa abre con el tamaño del xib, que es demasiado chico
      // para las tres columnas.
      await MainWindowSize.restore();
      await seedKeelAi();
      await seedRoadmapFormatSkill();
      await AssistantMcpServer.start();
      await UserToolsMcpServer.start();
      await SessionPlanMcpServer.ensureStarted();
      await RoadmapMcpServer.ensureStarted();
      await RequirementsMcpServer.ensureStarted();
      await JobsApiService.instance.notifier.start();
      _registerAgentBridgeHandler();
      // Respaldo periódico, y un último respaldo cuando la app se cierra.
      VaultAutoBackup.start();
      // Los catálogos se cargan mientras la app ya se ve, con la barra de
      // arriba prendida. Antes esto pasaba detrás de un gate que reemplazaba
      // la pantalla entera por un spinner que ni siquiera podía girar.
      unawaited(
        AppStatusService.instance.notifier.during(
          'Cargando tu sistema',
          awaitCatalogsReady,
        ),
      );
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
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await controller.show();
    // El foco viene con el show y no antes: la ventana se configuraba y se
    // enfocaba desde `initState`, con lo cual se mostraba dos veces y la
    // primera era sin píxeles.
    await windowManager.focus();
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
      // Arriba de todo, incluidos los paneles laterales: son rutas de este
      // mismo Navigator, y el `builder` los envuelve.
      builder: (context, child) => AppBusyOverlay(child: child!),
      home: const VaultBootGate(child: AgentsScreen()),
    );
  }
}
