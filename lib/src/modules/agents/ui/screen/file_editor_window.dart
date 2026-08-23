import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/app_locale.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';

import 'package:keel_ui/src/core/services/agent_bridge_channel.dart';
import 'package:keel_ui/src/modules/agents/model/file_editor_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/file_editor_content.dart';

class FileEditorWindow extends StatefulWidget {
  const FileEditorWindow({super.key, required this.arguments});

  final FileEditorWindowArguments arguments;

  @override
  State<FileEditorWindow> createState() => _FileEditorWindowState();
}

class _FileEditorWindowState extends State<FileEditorWindow> {
  String get _fileName => widget.arguments.fileEdit.path.split('/').last;

  @override
  void initState() {
    super.initState();
    unawaited(_configureWindow());
  }

  Future<void> _configureWindow() async {
    final options = WindowOptions(
      size: const Size(820, 640),
      minimumSize: const Size(560, 420),
      center: true,
      title: _fileName,
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

  Future<void> _askAboutLine({
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) {
    return agentBridgeChannel.invokeMethod('askAboutLine', {
      'agentId': widget.arguments.agentId,
      'filePath': filePath,
      'lineNumber': lineNumber,
      'lineContent': lineContent,
      'question': question,
    });
  }

  Future<void> _onManualEditSaved({
    required String filePath,
    required String beforeContent,
    required String afterContent,
  }) {
    return agentBridgeChannel.invokeMethod('recordManualEdit', {
      'agentId': widget.arguments.agentId,
      'filePath': filePath,
      'beforeContent': beforeContent,
      'afterContent': afterContent,
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _fileName,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      locale: localeForLanguageCode(widget.arguments.localeCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(title: Text(_fileName)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FileEditorContent(
            fileEdit: widget.arguments.fileEdit,
            onAskAboutLine: _askAboutLine,
            onManualEditSaved: _onManualEditSaved,
          ),
        ),
      ),
    );
  }
}
