import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuBarController = MenuBarController()

        // Check permissions on launch
        if PermissionsManager.checkAccessibility() != .granted {
            PermissionsManager.showPermissionAlert(for: .accessibility)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
