import Foundation
import Combine
import SwiftUI

enum AppThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var localizedTitleKey: String {
        switch self {
        case .system:
            return "settings_theme_system"
        case .light:
            return "settings_theme_light"
        case .dark:
            return "settings_theme_dark"
        }
    }
}

enum ListeningPortMigrationPolicy {
    static let defaultPort: UInt16 = 18661
    static let legacyDefaultPort: UInt16 = 19999

    static func resolvedPort(savedPort: Int, hasCustomizedPort: Bool) -> UInt16 {
        guard savedPort > 0, let resolvedSavedPort = UInt16(exactly: savedPort) else {
            return defaultPort
        }

        if resolvedSavedPort == legacyDefaultPort {
            return defaultPort
        }

        return resolvedSavedPort
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    enum DeprecatedPreferenceCleanupPolicy {
        static let legacyTextInjectionMethodKey = "textInjectionMethod"

        static func cleanup(defaults: UserDefaults) {
            defaults.removeObject(forKey: legacyTextInjectionMethodKey)
        }
    }

    // MARK: - Settings Keys
    private enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKey = "hotkeyKey"
        static let language = "language"
        static let uiLanguage = "uiLanguage"
        static let serverPort = "serverPort"
        static let hasCustomizedServerPort = "hasCustomizedServerPort"
        static let themePreference = "themePreference"
        static let automaticallyChecksForUpdates = "automaticallyChecksForUpdates"
        static let lastUpdateCheckDate = "lastUpdateCheckDate"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let hasShownUsageGuide = "hasShownUsageGuide"
    }

    // MARK: - Published Properties

    @Published var hotkeyModifiers: UInt {
        didSet {
            defaults.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers)
        }
    }

    @Published var hotkeyKey: UInt16 {
        didSet {
            defaults.set(Int(hotkeyKey), forKey: Keys.hotkeyKey)
        }
    }

    @Published var language: String {
        didSet {
            defaults.set(language, forKey: Keys.language)
        }
    }

    @Published var uiLanguage: String {
        didSet {
            defaults.set(uiLanguage, forKey: Keys.uiLanguage)
        }
    }

    @Published var serverPort: UInt16 {
        didSet {
            defaults.set(Int(serverPort), forKey: Keys.serverPort)
            defaults.set(true, forKey: Keys.hasCustomizedServerPort)
        }
    }

    @Published var themePreference: AppThemePreference {
        didSet {
            defaults.set(themePreference.rawValue, forKey: Keys.themePreference)
        }
    }

    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            defaults.set(automaticallyChecksForUpdates, forKey: Keys.automaticallyChecksForUpdates)
        }
    }

    @Published var lastUpdateCheckDate: Date? {
        didSet {
            defaults.set(lastUpdateCheckDate, forKey: Keys.lastUpdateCheckDate)
        }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    var hasShownUsageGuide: Bool {
        get { defaults.bool(forKey: Keys.hasShownUsageGuide) }
        set { defaults.set(newValue, forKey: Keys.hasShownUsageGuide) }
    }

    // MARK: - Initialization

    private init() {
        DeprecatedPreferenceCleanupPolicy.cleanup(defaults: defaults)

        // Load hotkey configuration
        let savedModifiers = UInt(defaults.integer(forKey: Keys.hotkeyModifiers))
        self.hotkeyModifiers = savedModifiers == 0 ? 0x80000 : savedModifiers

        let savedKey = defaults.integer(forKey: Keys.hotkeyKey)
        self.hotkeyKey = savedKey > 0 ? UInt16(savedKey) : 49 // Default: Space (0x31)

        // Load language (speech recognition language)
        if let savedLanguage = defaults.string(forKey: Keys.language) {
            self.language = savedLanguage
        } else {
            self.language = "zh-CN" // Default
        }

        // Load UI language
        if let savedUILanguage = defaults.string(forKey: Keys.uiLanguage) {
            self.uiLanguage = savedUILanguage
        } else {
            self.uiLanguage = "zh-CN" // Default
        }

        let savedPort = defaults.integer(forKey: Keys.serverPort)
        let hasCustomizedServerPort = defaults.bool(forKey: Keys.hasCustomizedServerPort)
        let resolvedPort = ListeningPortMigrationPolicy.resolvedPort(
            savedPort: savedPort,
            hasCustomizedPort: hasCustomizedServerPort
        )
        self.serverPort = resolvedPort
        if savedPort != Int(resolvedPort) {
            defaults.set(Int(resolvedPort), forKey: Keys.serverPort)
        }

        if let rawThemePreference = defaults.string(forKey: Keys.themePreference),
           let themePreference = AppThemePreference(rawValue: rawThemePreference) {
            self.themePreference = themePreference
        } else {
            self.themePreference = .system
        }

        self.automaticallyChecksForUpdates = defaults.object(forKey: Keys.automaticallyChecksForUpdates) as? Bool ?? false
        self.lastUpdateCheckDate = defaults.object(forKey: Keys.lastUpdateCheckDate) as? Date
    }

    // MARK: - Helper Methods

    func resetToDefaults() {
        hotkeyModifiers = 0x80000 // Option
        hotkeyKey = 49 // Space
        language = "zh-CN"
        uiLanguage = "zh-CN"
        serverPort = ListeningPortMigrationPolicy.defaultPort
        defaults.set(false, forKey: Keys.hasCustomizedServerPort)
        themePreference = .system
        automaticallyChecksForUpdates = false
        lastUpdateCheckDate = nil
    }
}
