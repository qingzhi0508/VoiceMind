import XCTest
import SwiftUI
@testable import VoiceMind

final class SpotlightActionStylePolicyTests: XCTestCase {
    @MainActor
    func testPrimaryActionUsesSolidFillForSingleLayerFeedback() {
        let style = SpotlightActionStylePolicy.style(for: .primary)

        XCTAssertEqual(style.borderColor, Color.clear)
        XCTAssertEqual(style.shadowOpacity, 0)
    }

    @MainActor
    func testSecondaryActionAvoidsWhiteOverlayCardLook() {
        let style = SpotlightActionStylePolicy.style(for: .secondary)

        XCTAssertNotEqual(style.fillColor, Color.white.opacity(0.75))
        XCTAssertNotEqual(style.borderColor, Color.clear)
        XCTAssertEqual(style.shadowOpacity, 0)
    }
}
