import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Cross-window bridge: secondary windows (e.g. the file editor) call into
/// the main window's live [AgentsViewModel] through this channel, since each
/// window runs its own Flutter engine with its own statics.
const agentBridgeChannel = WindowMethodChannel(
  'keel_ui/agent_bridge',
  mode: ChannelMode.unidirectional,
);
