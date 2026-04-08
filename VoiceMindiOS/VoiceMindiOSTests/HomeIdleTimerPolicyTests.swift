import SwiftUI
import Testing
@testable import VoiceMind

struct HomeIdleTimerPolicyTests {
    @Test
    func keepsScreenAwakeOnlyWhenHomeTabIsVisibleAndSceneIsActive() {
        #expect(
            HomeIdleTimerPolicy.shouldKeepScreenAwake(
                selectedTab: .home,
                scenePhase: .active
            )
        )

        #expect(
            !HomeIdleTimerPolicy.shouldKeepScreenAwake(
                selectedTab: .data,
                scenePhase: .active
            )
        )

        #expect(
            !HomeIdleTimerPolicy.shouldKeepScreenAwake(
                selectedTab: .settings,
                scenePhase: .active
            )
        )

        #expect(
            !HomeIdleTimerPolicy.shouldKeepScreenAwake(
                selectedTab: .home,
                scenePhase: .inactive
            )
        )

        #expect(
            !HomeIdleTimerPolicy.shouldKeepScreenAwake(
                selectedTab: .home,
                scenePhase: .background
            )
        )
    }
}
