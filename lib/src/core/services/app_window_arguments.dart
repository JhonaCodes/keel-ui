import 'dart:convert';

abstract class AppWindowArguments {
  const AppWindowArguments();

  static const String idMain = 'main';

  String get businessId;

  Map<String, dynamic> toJson();

  String toArguments() => jsonEncode({'businessId': businessId, ...toJson()});

  static Map<String, dynamic>? decode(String arguments) {
    if (arguments.isEmpty) return null;
    return jsonDecode(arguments) as Map<String, dynamic>;
  }
}

class MainWindowArguments extends AppWindowArguments {
  const MainWindowArguments();

  @override
  String get businessId => AppWindowArguments.idMain;

  @override
  Map<String, dynamic> toJson() => {};
}
