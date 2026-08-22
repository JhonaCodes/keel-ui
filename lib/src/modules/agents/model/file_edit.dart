class FileEdit {
  final String path;
  final String? beforeContent;
  final String afterContent;

  const FileEdit({
    required this.path,
    required this.beforeContent,
    required this.afterContent,
  });

  FileEdit copyWith({String? path}) => FileEdit(
    path: path ?? this.path,
    beforeContent: beforeContent,
    afterContent: afterContent,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'beforeContent': beforeContent,
    'afterContent': afterContent,
  };

  factory FileEdit.fromJson(Map<String, dynamic> json) {
    return FileEdit(
      path: json['path'] as String,
      beforeContent: json['beforeContent'] as String?,
      afterContent: json['afterContent'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileEdit &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          beforeContent == other.beforeContent &&
          afterContent == other.afterContent;

  @override
  int get hashCode => Object.hash(path, beforeContent, afterContent);

  @override
  String toString() => 'FileEdit(path: $path)';
}
