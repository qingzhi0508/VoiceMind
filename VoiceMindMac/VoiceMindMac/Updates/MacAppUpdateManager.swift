import AppKit
import Combine
import Foundation

enum MacAppUpdateInstallationMode: Equatable {
    case diskImage
    case zipArchive
    case package
    case openDownloadedFile
}

struct MacAppReleaseAsset: Equatable {
    let name: String
    let downloadURL: URL
}

struct MacAppRelease: Equatable {
    let version: String
    let build: String?
    let publishedAt: Date?
    let notes: String?
    let assets: [MacAppReleaseAsset]
}

@MainActor
final class MacAppUpdateManager: ObservableObject {
    static let shared = MacAppUpdateManager()

    @Published private(set) var latestRelease: MacAppRelease?
    @Published private(set) var selectedAsset: MacAppReleaseAsset?
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var isDownloadingUpdate = false
    @Published private(set) var statusMessage: String = ""

    private enum Constants {
        static let owner = "qingzhi0508"
        static let repository = "VoiceMind"
        static let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    }

    private struct GitHubReleaseResponse: Decodable {
        let tagName: String
        let body: String?
        let publishedAt: Date?
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case publishedAt = "published_at"
            case assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    private init() {
        statusMessage = AppLocalization.localizedString("about_update_idle")
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var currentBuild: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    var currentVersionDisplay: String {
        if let currentBuild, !currentBuild.isEmpty {
            return "\(currentVersion) (\(currentBuild))"
        }

        return currentVersion
    }

    var latestVersionSummary: String? {
        guard let latestRelease else { return nil }

        if let build = latestRelease.build, !build.isEmpty {
            return "\(latestRelease.version) (\(build))"
        }

        return latestRelease.version
    }

    var latestReleaseNotesSummary: String? {
        guard let notes = latestRelease?.notes?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !notes.isEmpty else {
            return nil
        }

        let lines = notes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        return lines.prefix(5).joined(separator: "\n")
    }

    var latestPublishedDateDescription: String? {
        guard let publishedAt = latestRelease?.publishedAt else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppSettings.shared.uiLanguage)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: publishedAt)
    }

    func checkForUpdates(userInitiated: Bool = true) async {
        isCheckingForUpdates = true
        latestRelease = nil
        selectedAsset = nil
        statusMessage = AppLocalization.localizedString("about_update_checking")

        defer {
            isCheckingForUpdates = false
        }

        do {
            let release = try await fetchLatestRelease()
            AppSettings.shared.lastUpdateCheckDate = Date()

            guard Self.isRemoteVersionNewer(
                remoteVersion: release.version,
                remoteBuild: release.build,
                localVersion: currentVersion,
                localBuild: currentBuild
            ) else {
                latestRelease = nil
                selectedAsset = nil
                statusMessage = AppLocalization.localizedString("about_update_up_to_date")
                return
            }

            guard let asset = Self.selectPreferredAsset(from: release, architecture: Self.currentArchitecture) else {
                latestRelease = release
                selectedAsset = nil
                statusMessage = AppLocalization.localizedString("about_update_no_installer")
                return
            }

            latestRelease = release
            selectedAsset = asset
            statusMessage = String(
                format: AppLocalization.localizedString("about_update_available_format"),
                latestVersionSummary ?? release.version
            )

            if !userInitiated && AppSettings.shared.automaticallyChecksForUpdates {
                await downloadAndInstallLatestRelease()
            }
        } catch {
            latestRelease = nil
            selectedAsset = nil
            statusMessage = error.localizedDescription
        }
    }

    func downloadAndInstallLatestRelease() async {
        guard let asset = selectedAsset else {
            statusMessage = AppLocalization.localizedString("about_update_no_installer")
            return
        }

        isDownloadingUpdate = true
        statusMessage = AppLocalization.localizedString("about_update_downloading")

        defer {
            isDownloadingUpdate = false
        }

        do {
            let downloadedURL = try await downloadAsset(asset)
            let installationMode = Self.installationMode(forAssetNamed: asset.name)

            switch installationMode {
            case .diskImage, .zipArchive:
                statusMessage = AppLocalization.localizedString("about_update_installing")
                try scheduleDirectInstallation(
                    of: downloadedURL,
                    mode: installationMode
                )
            case .package, .openDownloadedFile:
                let opened = NSWorkspace.shared.open(downloadedURL)
                guard opened else {
                    throw MacAppUpdateError.unableToOpenInstaller
                }
                statusMessage = AppLocalization.localizedString("about_update_installer_opened")
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func performAutomaticUpdateCheckIfNeeded() async {
        guard AppSettings.shared.automaticallyChecksForUpdates else {
            return
        }

        if let lastCheckDate = AppSettings.shared.lastUpdateCheckDate,
           Date().timeIntervalSince(lastCheckDate) < Constants.automaticCheckInterval {
            return
        }

        await checkForUpdates(userInitiated: false)
    }

    private func fetchLatestRelease() async throws -> MacAppRelease {
        let url = URL(string: "https://api.github.com/repos/\(Constants.owner)/\(Constants.repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("VoiceMindMac", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MacAppUpdateError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw MacAppUpdateError.releaseRepositoryUnavailable
            }

            throw MacAppUpdateError.httpStatus(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let releaseResponse = try decoder.decode(GitHubReleaseResponse.self, from: data)
            let version = Self.normalizedVersionString(releaseResponse.tagName)
            let build = Self.extractBuildNumber(from: releaseResponse.tagName)

            return MacAppRelease(
                version: version,
                build: build,
                publishedAt: releaseResponse.publishedAt,
                notes: releaseResponse.body,
                assets: releaseResponse.assets.map {
                    MacAppReleaseAsset(
                        name: $0.name,
                        downloadURL: $0.browserDownloadURL
                    )
                }
            )
        } catch {
            throw MacAppUpdateError.invalidReleasePayload
        }
    }

    private func downloadAsset(_ asset: MacAppReleaseAsset) async throws -> URL {
        let updatesDirectory = try createUpdatesDirectoryIfNeeded()
        let destinationURL = updatesDirectory.appendingPathComponent(asset.name)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        var request = URLRequest(url: asset.downloadURL)
        request.setValue("VoiceMindMac", forHTTPHeaderField: "User-Agent")
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MacAppUpdateError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MacAppUpdateError.httpStatus(httpResponse.statusCode)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func createUpdatesDirectoryIfNeeded() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let updatesDirectory = applicationSupportDirectory
            .appendingPathComponent("VoiceMind", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
        try FileManager.default.createDirectory(at: updatesDirectory, withIntermediateDirectories: true)
        return updatesDirectory
    }

    private func scheduleDirectInstallation(of downloadedURL: URL, mode: MacAppUpdateInstallationMode) throws {
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        let targetAppURL = Self.preferredInstallDestination(forCurrentBundleURL: currentBundleURL)
        let helperScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicemind-update-\(UUID().uuidString).sh", isDirectory: false)

        let helperScript = Self.backgroundInstallerScript(
            downloadedAssetURL: downloadedURL,
            targetApplicationURL: targetAppURL,
            installationMode: mode,
            currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )

        do {
            try helperScript.write(to: helperScriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperScriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [helperScriptURL.path]
            try process.run()
        } catch {
            throw MacAppUpdateError.unableToPrepareInstallation
        }

        statusMessage = AppLocalization.localizedString("about_update_installed_relaunching")
        NSApp.terminate(nil)
    }

    nonisolated static var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    nonisolated static func selectPreferredAsset(from release: MacAppRelease, architecture: String) -> MacAppReleaseAsset? {
        let supportedAssets = release.assets.filter { asset in
            let lowercasedName = asset.name.lowercased()
            let matchesExtension = lowercasedName.hasSuffix(".dmg")
                || lowercasedName.hasSuffix(".zip")
                || lowercasedName.hasSuffix(".pkg")
            let matchesPlatform = lowercasedName.contains("mac")
                || lowercasedName.contains("macos")
                || lowercasedName.contains("darwin")
            return matchesExtension && matchesPlatform
        }

        guard !supportedAssets.isEmpty else {
            return nil
        }

        let platformKeywords = architecture.lowercased().contains("arm")
            ? ["universal", "arm64", "apple-silicon"]
            : ["universal", "x86_64", "intel"]

        if let preferredAsset = supportedAssets.first(where: { asset in
            let lowercasedName = asset.name.lowercased()
            return platformKeywords.contains(where: lowercasedName.contains)
        }) {
            return preferredAsset
        }

        if let dmgAsset = supportedAssets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
            return dmgAsset
        }

        if let zipAsset = supportedAssets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) {
            return zipAsset
        }

        return supportedAssets.first
    }

    nonisolated static func installationMode(forAssetNamed name: String) -> MacAppUpdateInstallationMode {
        let lowercasedName = name.lowercased()

        if lowercasedName.hasSuffix(".dmg") {
            return .diskImage
        }

        if lowercasedName.hasSuffix(".zip") {
            return .zipArchive
        }

        if lowercasedName.hasSuffix(".pkg") {
            return .package
        }

        return .openDownloadedFile
    }

    nonisolated static func preferredInstallDestination(forCurrentBundleURL currentBundleURL: URL) -> URL {
        let standardizedBundleURL = currentBundleURL.standardizedFileURL
        let bundlePath = standardizedBundleURL.path
        let applicationsDirectory = "/Applications"
        let userApplicationsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path

        if bundlePath.hasPrefix(applicationsDirectory + "/") || bundlePath == applicationsDirectory {
            return standardizedBundleURL
        }

        if bundlePath.hasPrefix(userApplicationsDirectory + "/") || bundlePath == userApplicationsDirectory {
            return standardizedBundleURL
        }

        return URL(fileURLWithPath: applicationsDirectory, isDirectory: true)
            .appendingPathComponent(standardizedBundleURL.lastPathComponent, isDirectory: true)
    }

    nonisolated static func isRemoteVersionNewer(
        remoteVersion: String,
        remoteBuild: String?,
        localVersion: String,
        localBuild: String?
    ) -> Bool {
        let remoteComponents = versionComponents(from: remoteVersion)
        let localComponents = versionComponents(from: localVersion)

        let upperBound = max(remoteComponents.count, localComponents.count)
        for index in 0..<upperBound {
            let remoteValue = remoteComponents.indices.contains(index) ? remoteComponents[index] : 0
            let localValue = localComponents.indices.contains(index) ? localComponents[index] : 0

            if remoteValue != localValue {
                return remoteValue > localValue
            }
        }

        let remoteBuildValue = Int(remoteBuild ?? "") ?? 0
        let localBuildValue = Int(localBuild ?? "") ?? 0
        return remoteBuildValue > localBuildValue
    }

    nonisolated private static func versionComponents(from version: String) -> [Int] {
        normalizedVersionString(version)
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    nonisolated private static func normalizedVersionString(_ value: String) -> String {
        let trimmedValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.caseInsensitive, .anchored])

        return trimmedValue
            .split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? trimmedValue
    }

    nonisolated private static func extractBuildNumber(from value: String) -> String? {
        let components = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "+", omittingEmptySubsequences: true)
        guard components.count > 1 else {
            return nil
        }

        return String(components[1])
    }

    private static func backgroundInstallerScript(
        downloadedAssetURL: URL,
        targetApplicationURL: URL,
        installationMode: MacAppUpdateInstallationMode,
        currentProcessIdentifier: Int32
    ) -> String {
        let downloadedAssetPath = shellEscaped(downloadedAssetURL.path)
        let targetApplicationPath = shellEscaped(targetApplicationURL.path)
        let localizedInstallingFallback = shellEscaped(
            AppLocalization.localizedString("about_update_error_prepare_install")
        )
        let modeName: String = switch installationMode {
        case .diskImage:
            "diskImage"
        case .zipArchive:
            "zipArchive"
        case .package:
            "package"
        case .openDownloadedFile:
            "openDownloadedFile"
        }

        return """
        #!/bin/zsh
        set -eu

        asset_path=\(downloadedAssetPath)
        target_app=\(targetApplicationPath)
        mode=\(shellEscaped(modeName))
        app_pid=\(currentProcessIdentifier)
        fallback_message=\(localizedInstallingFallback)

        mounted_volume=""
        extracted_directory=""
        install_script=""

        cleanup() {
          if [ -n "$mounted_volume" ] && [ -d "$mounted_volume" ]; then
            /usr/bin/hdiutil detach "$mounted_volume" -force >/dev/null 2>&1 || true
          fi

          if [ -n "$extracted_directory" ] && [ -d "$extracted_directory" ]; then
            /bin/rm -rf "$extracted_directory"
          fi

          if [ -n "$install_script" ] && [ -f "$install_script" ]; then
            /bin/rm -f "$install_script"
          fi

          /bin/rm -f "$0"
        }

        fallback_to_manual_install() {
          /usr/bin/open "$asset_path" >/dev/null 2>&1 || true
          /usr/bin/logger -t VoiceMind "$fallback_message"
        }

        wait_for_app_exit() {
          while /bin/kill -0 "$app_pid" >/dev/null 2>&1; do
            /bin/sleep 0.5
          done
        }

        write_install_script() {
          local source_app="$1"
          local target_parent
          local target_name
          local temp_target
          local source_q
          local target_q
          local target_parent_q
          local temp_target_q

          target_parent=$(/usr/bin/dirname "$target_app")
          target_name=$(/usr/bin/basename "$target_app")
          temp_target="$target_parent/.${target_name}.update.$$"

          source_q=$(printf "%q" "$source_app")
          target_q=$(printf "%q" "$target_app")
          target_parent_q=$(printf "%q" "$target_parent")
          temp_target_q=$(printf "%q" "$temp_target")

          install_script=$(/usr/bin/mktemp /tmp/voicemind-install.XXXXXX.sh)
          cat > "$install_script" <<EOS
        #!/bin/zsh
        set -eu
        /bin/mkdir -p $target_parent_q
        /bin/rm -rf $temp_target_q
        /usr/bin/ditto $source_q $temp_target_q
        /bin/rm -rf $target_q
        /bin/mv $temp_target_q $target_q
        EOS
          /bin/chmod 700 "$install_script"
        }

        run_install_script() {
          local target_parent
          target_parent=$(/usr/bin/dirname "$target_app")

          if [ -w "$target_parent" ] && { [ ! -e "$target_app" ] || [ -w "$target_app" ]; }; then
            /bin/zsh "$install_script"
          else
            /usr/bin/osascript -e "do shell script \\"/bin/zsh $install_script\\" with administrator privileges"
          fi
        }

        install_from_disk_image() {
          local attach_output
          local source_app

          attach_output=$(/usr/bin/hdiutil attach -nobrowse -readonly "$asset_path" 2>/dev/null)
          mounted_volume=$(printf "%s\\n" "$attach_output" | /usr/bin/awk 'match($0, /\\/Volumes\\/.*/) { print substr($0, RSTART); exit }')
          [ -n "$mounted_volume" ] || return 1

          source_app=$(/usr/bin/find "$mounted_volume" -maxdepth 2 -name "*.app" -print -quit)
          [ -n "$source_app" ] || return 1

          write_install_script "$source_app"
          run_install_script
        }

        install_from_zip_archive() {
          local source_app

          extracted_directory=$(/usr/bin/mktemp -d /tmp/voicemind-update.XXXXXX)
          /usr/bin/ditto -x -k "$asset_path" "$extracted_directory"

          source_app=$(/usr/bin/find "$extracted_directory" -maxdepth 3 -name "*.app" -print -quit)
          [ -n "$source_app" ] || return 1

          write_install_script "$source_app"
          run_install_script
        }

        trap cleanup EXIT

        wait_for_app_exit

        case "$mode" in
          diskImage)
            install_from_disk_image || {
              fallback_to_manual_install
              exit 1
            }
            ;;
          zipArchive)
            install_from_zip_archive || {
              fallback_to_manual_install
              exit 1
            }
            ;;
          *)
            fallback_to_manual_install
            exit 1
            ;;
        esac

        /usr/bin/open "$target_app" >/dev/null 2>&1 || true
        /bin/rm -f "$asset_path"
        """
    }

    private static func shellEscaped(_ value: String) -> String {
        if value.isEmpty {
            return "''"
        }

        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

private enum MacAppUpdateError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case invalidReleasePayload
    case releaseRepositoryUnavailable
    case unableToOpenInstaller
    case unableToPrepareInstallation

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return AppLocalization.localizedString("about_update_error_invalid_response")
        case .httpStatus(let statusCode):
            return String(
                format: AppLocalization.localizedString("about_update_error_http_status_format"),
                "\(statusCode)"
            )
        case .invalidReleasePayload:
            return AppLocalization.localizedString("about_update_error_invalid_payload")
        case .releaseRepositoryUnavailable:
            return AppLocalization.localizedString("about_update_error_repo_unavailable")
        case .unableToOpenInstaller:
            return AppLocalization.localizedString("about_update_error_open_installer")
        case .unableToPrepareInstallation:
            return AppLocalization.localizedString("about_update_error_prepare_install")
        }
    }
}
