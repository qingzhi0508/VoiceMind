import XCTest
@testable import VoiceMind

final class SherpaOnnxModelDirectoryResolverTests: XCTestCase {
    func testPreferredLegacyHomeDirectoryFallsBackToRealUserHomeWhenCurrentHomeIsSandboxContainer() {
        let currentHome = URL(fileURLWithPath: "/Users/cayden/Library/Containers/cayden.VoiceMind/Data", isDirectory: true)
        let realUserHome = URL(fileURLWithPath: "/Users/cayden", isDirectory: true)

        let resolvedHome = SherpaOnnxModelDirectoryResolver.preferredLegacyHomeDirectory(
            currentHomeDirectory: currentHome,
            appBundleIdentifier: "cayden.VoiceMind",
            passwdHomeDirectory: realUserHome
        )

        XCTAssertEqual(resolvedHome.standardizedFileURL, realUserHome.standardizedFileURL)
    }

    func testPreferredLegacyHomeDirectoryKeepsCurrentHomeWhenAlreadyOutsideSandboxContainer() {
        let currentHome = URL(fileURLWithPath: "/Users/cayden", isDirectory: true)
        let realUserHome = URL(fileURLWithPath: "/Users/cayden", isDirectory: true)

        let resolvedHome = SherpaOnnxModelDirectoryResolver.preferredLegacyHomeDirectory(
            currentHomeDirectory: currentHome,
            appBundleIdentifier: "cayden.VoiceMind",
            passwdHomeDirectory: realUserHome
        )

        XCTAssertEqual(resolvedHome.standardizedFileURL, currentHome.standardizedFileURL)
    }

    func testPreferredLegacyHomeDirectoryKeepsCurrentHomeWithoutBundleIdentifier() {
        let currentHome = URL(fileURLWithPath: "/Users/cayden/Library/Containers/cayden.VoiceMind/Data", isDirectory: true)
        let realUserHome = URL(fileURLWithPath: "/Users/cayden", isDirectory: true)

        let resolvedHome = SherpaOnnxModelDirectoryResolver.preferredLegacyHomeDirectory(
            currentHomeDirectory: currentHome,
            appBundleIdentifier: nil,
            passwdHomeDirectory: realUserHome
        )

        XCTAssertEqual(resolvedHome.standardizedFileURL, currentHome.standardizedFileURL)
    }
}
