import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let resources = Bundle.main.resourceURL
    let bundled = resources?.appendingPathComponent("native/macos_arm64")
    let workspace = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("../keel-core/native/macos_arm64")
    if let bundled, FileManager.default.fileExists(atPath: bundled.path) {
      setenv("LITERTLM_LIB_DIR", bundled.path, 0)
    } else if FileManager.default.fileExists(atPath: workspace.path) {
      setenv("LITERTLM_LIB_DIR", workspace.standardizedFileURL.path, 0)
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
