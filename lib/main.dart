import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:keel_ui/src/core/services/agent_bridge_channel.dart';
import 'package:keel_ui/src/core/services/app_window_arguments.dart';
import 'package:keel_ui/src/core/services/legacy_json_migration.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/file_editor_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/agents_screen.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/file_editor_window.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/model/keelai_seed.dart';

Future<void> main(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await LocalDatabase.ensureInitialized();
  await migrateLegacyJsonIfNeeded();
  await seedKeelAi();
  await AssistantMcpServer.start();

  final windowController = await WindowController.fromCurrentEngine();
  final json = AppWindowArguments.decode(windowController.arguments);
  final businessId =
      json?['businessId'] as String? ?? AppWindowArguments.idMain;

  switch (businessId) {
    case FileEditorWindowArguments.id:
      runApp(
        FileEditorWindow(arguments: FileEditorWindowArguments.fromJson(json!)),
      );

    // Sub-windows (e.g. the file editor) add their own case here, using
    // AppWindowArguments as the JSON contract and window_manager to size
    // and show themselves — see openAppWindow in app_window_service.dart.
    case AppWindowArguments.idMain:
    default:
      _registerAgentBridgeHandler();
      runApp(const KeelUiApp());
  }
}

void _registerAgentBridgeHandler() {
  agentBridgeChannel.setMethodCallHandler((call) async {
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
