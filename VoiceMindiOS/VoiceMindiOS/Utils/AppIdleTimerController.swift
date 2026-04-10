import SwiftUI
import UIKit

enum HomeIdleTimerPolicy {
    static func shouldKeepScreenAwake(
        selectedTab: ContentTab,
        scenePhase: ScenePhase
    ) -> Bool {
        selectedTab == .home && scenePhase == .active
    }
}

@MainActor
final class AppIdleTimerController {
    static let shared = AppIdleTimerController()

    private init() {}

    func setKeepsScreenAwake(_ isEnabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = isEnabled
    }
}
