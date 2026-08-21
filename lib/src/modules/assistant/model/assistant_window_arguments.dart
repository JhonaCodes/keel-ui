import 'package:keel_ui/src/core/services/app_window_arguments.dart';

/// Launch arguments for the dedicated Keel AI window. Carries no payload:
/// the window is a pure presentation client — everything it shows arrives
/// afterwards as pushed [AssistantWindowState] snapshots, and everything the
/// user does travels back as `assistant.*` bridge calls.
class AssistantWindowArguments extends AppWindowArguments {
  static const String id = 'assistant_window';

  @override
  String get businessId => id;

  @override
  Map<String, dynamic> toJson() => const {};
}
