import 'package:keel_ui/src/core/services/app_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';

class FileEditorWindowArguments extends AppWindowArguments {
  static const String id = 'file_editor';

  final FileEdit fileEdit;
  final String agentId;

  /// El idioma elegido en Ajustes (`'en'`, `'es_CO'`, o `''` para el del
  /// sistema). Esta ventana es un engine sin base propia (ver
  /// `LocalDatabase.markUnavailable` en `main.dart`) y arranca una sola vez
  /// con estos argumentos — a diferencia de la ventana del asistente, no hay
  /// un canal para empujarle un cambio de idioma después de abierta.
  final String localeCode;

  const FileEditorWindowArguments({
    required this.fileEdit,
    required this.agentId,
    required this.localeCode,
  });

  factory FileEditorWindowArguments.fromJson(Map<String, dynamic> json) {
    return FileEditorWindowArguments(
      fileEdit: FileEdit.fromJson(json['fileEdit'] as Map<String, dynamic>),
      agentId: json['agentId'] as String,
      localeCode: json['localeCode'] as String? ?? '',
    );
  }

  @override
  String get businessId => id;

  @override
  Map<String, dynamic> toJson() => {
    'fileEdit': fileEdit.toJson(),
    'agentId': agentId,
    'localeCode': localeCode,
  };
}
