import Testing
@testable import VoiceMind

struct ThemedPrimaryTabPolicyTests {
    @Test
    func homeDataAndSettingsAllUseThemedCanvas() {
        #expect(ThemedPrimaryTabPolicy.usesCanvasBackground(for: .home))
        #expect(ThemedPrimaryTabPolicy.usesCanvasBackground(for: .data))
        #expect(ThemedPrimaryTabPolicy.usesCanvasBackground(for: .settings))
    }
}
