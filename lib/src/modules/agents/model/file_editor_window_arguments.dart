import 'package:keel_ui/src/core/services/app_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';

class FileEditorWindowArguments extends AppWindowArguments {
  static const String id = 'file_editor';

  final FileEdit fileEdit;
  final String agentId;

  const FileEditorWindowArguments({
    required this.fileEdit,
    required this.agentId,
  });

  factory FileEditorWindowArguments.fromJson(Map<String, dynamic> json) {
    return FileEditorWindowArguments(
      fileEdit: FileEdit.fromJson(json['fileEdit'] as Map<String, dynamic>),
      agentId: json['agentId'] as String,
    );
  }

  @override
  String get businessId => id;

  @override
  Map<String, dynamic> toJson() => {
    'fileEdit': fileEdit.toJson(),
    'agentId': agentId,
  };
}
