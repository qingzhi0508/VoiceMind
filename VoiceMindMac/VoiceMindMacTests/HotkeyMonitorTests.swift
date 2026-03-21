import XCTest
@testable import VoiceMind

final class HotkeyMonitorTests: XCTestCase {
    func testHotkeyMonitoringOnlyRequiresInputMonitoringPermission() {
        XCTAssertEqual(
            HotkeyMonitor.missingPermissionsForMonitoring(
                accessibility: .denied,
                inputMonitoring: .granted
            ),
            []
        )
    }

    func testHotkeyMonitoringReportsMissingInputMonitoringPermission() {
        XCTAssertEqual(
            HotkeyMonitor.missingPermissionsForMonitoring(
                accessibility: .granted,
                inputMonitoring: .denied
            ),
            [.inputMonitoring]
        )
    }
}
