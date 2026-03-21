import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Settings Keys
    private enum Keys {
        static let textInjectionMethod = "textInjectionMethod"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKey = "hotkeyKey"
        static let language = "language"
        static let serverPort = "serverPort"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let hasShownUsageGuide = "hasShownUsageGuide"
    }

    // MARK: - Published Properties

    @Published var textInjectionMethod: TextInjectionMethod {
        didSet {
            defaults.set(textInjectionMethod.rawValue, forKey: Keys.textInjectionMethod)
        }
    }

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

    @Published var serverPort: UInt16 {
        didSet {
            defaults.set(Int(serverPort), forKey: Keys.serverPort)
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
        // Always use clipboard paste for the most reliable text injection behavior.
        self.textInjectionMethod = .clipboard
        defaults.set(TextInjectionMethod.clipboard.rawValue, forKey: Keys.textInjectionMethod)

        // Load hotkey configuration
        let savedModifiers = UInt(defaults.integer(forKey: Keys.hotkeyModifiers))
        self.hotkeyModifiers = savedModifiers == 0 ? 0x80000 : savedModifiers

        let savedKey = defaults.integer(forKey: Keys.hotkeyKey)
        self.hotkeyKey = savedKey > 0 ? UInt16(savedKey) : 49 // Default: Space (0x31)

        // Load language
        if let savedLanguage = defaults.string(forKey: Keys.language) {
            self.language = savedLanguage
        } else {
            self.language = "zh-CN" // Default
        }

        let savedPort = defaults.integer(forKey: Keys.serverPort)
        self.serverPort = savedPort > 0 ? UInt16(savedPort) : 8899
    }

    // MARK: - Helper Methods

    func resetToDefaults() {
        textInjectionMethod = .clipboard
        hotkeyModifiers = 0x80000 // Option
        hotkeyKey = 49 // Space
        language = "zh-CN"
        serverPort = 8899
    }
}
