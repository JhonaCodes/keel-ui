import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:keel_ui/src/core/services/app_window_arguments.dart';

/// Opens a new native OS window running its own Flutter engine. [arguments]
/// decides (in the new engine's `main()`) which widget tree that window
/// runs — see [AppWindowArguments].
Future<void> openAppWindow(AppWindowArguments arguments) async {
  final controller = await WindowController.create(
    WindowConfiguration(
      hiddenAtLaunch: true,
      arguments: arguments.toArguments(),
    ),
  );
  await controller.show();
}
