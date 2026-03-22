import CoreGraphics
import Testing
@testable import VoiceMind

struct PageSwipeNavigationPolicyTests {
    @Test
    func firstPageIgnoresRightSwipeBeyondThreshold() {
        #expect(
            PageSwipeNavigationPolicy.destinationPage(
                from: 0,
                translationWidth: 90,
                translationHeight: 4,
                pageCount: 2
            ) == nil
        )
    }

    @Test
    func firstPageNavigatesLeftWhenSwipeExceedsThreshold() {
        #expect(
            PageSwipeNavigationPolicy.destinationPage(
                from: 0,
                translationWidth: -90,
                translationHeight: 4,
                pageCount: 2
            ) == 1
        )
    }

    @Test
    func secondPageNavigatesRightWhenSwipeExceedsThreshold() {
        #expect(
            PageSwipeNavigationPolicy.destinationPage(
                from: 1,
                translationWidth: 90,
                translationHeight: 4,
                pageCount: 2
            ) == 0
        )
    }

    @Test
    func ignoresVerticalDominantDrags() {
        #expect(
            PageSwipeNavigationPolicy.destinationPage(
                from: 1,
                translationWidth: 90,
                translationHeight: 120,
                pageCount: 2
            ) == nil
        )
    }

    @Test
    func ignoresShortHorizontalDrags() {
        #expect(
            PageSwipeNavigationPolicy.destinationPage(
                from: 1,
                translationWidth: 40,
                translationHeight: 2,
                pageCount: 2
            ) == nil
        )
    }
}
