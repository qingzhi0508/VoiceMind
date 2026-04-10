import XCTest
@testable import VoiceMind

@MainActor
final class MacAppUpdateManagerTests: XCTestCase {
    func testVersionComparisonTreatsHigherSemanticVersionAsNewer() {
        XCTAssertTrue(
            MacAppUpdateManager.isRemoteVersionNewer(
                remoteVersion: "v1.2.0",
                remoteBuild: nil,
                localVersion: "1.1.9",
                localBuild: "5"
            )
        )
    }

    func testVersionComparisonFallsBackToBuildNumberWhenSemanticVersionMatches() {
        XCTAssertTrue(
            MacAppUpdateManager.isRemoteVersionNewer(
                remoteVersion: "1.0.0",
                remoteBuild: "12",
                localVersion: "1.0.0",
                localBuild: "11"
            )
        )
        XCTAssertFalse(
            MacAppUpdateManager.isRemoteVersionNewer(
                remoteVersion: "1.0.0",
                remoteBuild: "11",
                localVersion: "1.0.0",
                localBuild: "11"
            )
        )
    }

    func testSelectsUniversalOrArmAssetForAppleSilicon() throws {
        let release = MacAppRelease(
            version: "1.2.3",
            build: "5",
            publishedAt: nil,
            notes: nil,
            assets: [
                MacAppReleaseAsset(
                    name: "VoiceMind-windows-x64.msi",
                    downloadURL: URL(string: "https://example.com/windows.msi")!
                ),
                MacAppReleaseAsset(
                    name: "VoiceMind-macos-universal.dmg",
                    downloadURL: URL(string: "https://example.com/universal.dmg")!
                ),
                MacAppReleaseAsset(
                    name: "VoiceMind-macos-intel.dmg",
                    downloadURL: URL(string: "https://example.com/intel.dmg")!
                )
            ]
        )

        let selectedAsset = try XCTUnwrap(
            MacAppUpdateManager.selectPreferredAsset(
                from: release,
                architecture: "arm64"
            )
        )

        XCTAssertEqual(selectedAsset.name, "VoiceMind-macos-universal.dmg")
    }

    func testSelectsIntelAssetWhenRunningOnIntelMac() throws {
        let release = MacAppRelease(
            version: "1.2.3",
            build: "5",
            publishedAt: nil,
            notes: nil,
            assets: [
                MacAppReleaseAsset(
                    name: "VoiceMind-macos-arm64.dmg",
                    downloadURL: URL(string: "https://example.com/arm64.dmg")!
                ),
                MacAppReleaseAsset(
                    name: "VoiceMind-macos-x86_64.zip",
                    downloadURL: URL(string: "https://example.com/intel.zip")!
                )
            ]
        )

        let selectedAsset = try XCTUnwrap(
            MacAppUpdateManager.selectPreferredAsset(
                from: release,
                architecture: "x86_64"
            )
        )

        XCTAssertEqual(selectedAsset.name, "VoiceMind-macos-x86_64.zip")
    }

    func testInstallationModePrefersDirectInstallForDiskImagesAndArchives() {
        XCTAssertEqual(
            MacAppUpdateManager.installationMode(forAssetNamed: "VoiceMind-macos-universal.dmg"),
            .diskImage
        )
        XCTAssertEqual(
            MacAppUpdateManager.installationMode(forAssetNamed: "VoiceMind-macos-universal.zip"),
            .zipArchive
        )
        XCTAssertEqual(
            MacAppUpdateManager.installationMode(forAssetNamed: "VoiceMind-macos.pkg"),
            .package
        )
        XCTAssertEqual(
            MacAppUpdateManager.installationMode(forAssetNamed: "VoiceMind-macos.txt"),
            .openDownloadedFile
        )
    }

    func testPreferredInstallDestinationKeepsExistingApplicationsInstall() {
        let systemApplicationsURL = URL(fileURLWithPath: "/Applications/VoiceMind.app")
        XCTAssertEqual(
            MacAppUpdateManager.preferredInstallDestination(forCurrentBundleURL: systemApplicationsURL),
            systemApplicationsURL
        )

        let userApplicationsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("VoiceMind.app", isDirectory: true)
        XCTAssertEqual(
            MacAppUpdateManager.preferredInstallDestination(forCurrentBundleURL: userApplicationsURL),
            userApplicationsURL
        )
    }

    func testPreferredInstallDestinationFallsBackToSystemApplicationsForMountedOrDevelopmentBuilds() {
        let mountedBundleURL = URL(fileURLWithPath: "/Volumes/VoiceMind 1.0/VoiceMind.app")
        XCTAssertEqual(
            MacAppUpdateManager.preferredInstallDestination(forCurrentBundleURL: mountedBundleURL).path,
            URL(fileURLWithPath: "/Applications/VoiceMind.app").path
        )

        let developmentBundleURL = URL(fileURLWithPath: "/tmp/VoiceMind.app")
        XCTAssertEqual(
            MacAppUpdateManager.preferredInstallDestination(forCurrentBundleURL: developmentBundleURL).path,
            URL(fileURLWithPath: "/Applications/VoiceMind.app").path
        )
    }
}
