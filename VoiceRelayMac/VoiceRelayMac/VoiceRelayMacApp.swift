import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        menuBarController = MenuBarController()
        menuBarController.showMainWindow()

        let accessibilityStatus = PermissionsManager.checkAccessibility()
        if accessibilityStatus != .granted {
            PermissionsManager.requestAccessibility()
        }

        let inputMonitoringStatus = PermissionsManager.checkInputMonitoring()
        if inputMonitoringStatus != .granted {
            PermissionsManager.requestInputMonitoring()
        }

        menuBarController.refreshPermissionState()
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
