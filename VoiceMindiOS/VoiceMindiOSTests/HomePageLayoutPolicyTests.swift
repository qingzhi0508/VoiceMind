import Testing
@testable import VoiceMind

struct HomePageLayoutPolicyTests {
    @Test
    func allPrimaryTabsDoNotUseOuterPagePadding() {
        #expect(!HomePageLayoutPolicy.usesOuterPagePadding(for: .home))
        #expect(!HomePageLayoutPolicy.usesOuterPagePadding(for: .data))
        #expect(!HomePageLayoutPolicy.usesOuterPagePadding(for: .settings))
    }
}
