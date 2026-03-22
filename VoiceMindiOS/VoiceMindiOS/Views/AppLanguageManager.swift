import Foundation

enum AppLanguageManager {
    static func defaultLanguageCode() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        return normalized(preferred)
    }

    static func setLanguage(_ code: String) {
        let normalizedCode = normalized(code)
        UserDefaults.standard.set([normalizedCode], forKey: "AppleLanguages")
        UserDefaults.standard.set(normalizedCode, forKey: "app_language")
        UserDefaults.standard.synchronize()
    }

    static func restartAfterLanguageChange(_ terminationHandler: () -> Void = {}) {
        // iOS apps should not terminate themselves after a settings change.
        _ = terminationHandler
    }

    static func normalized(_ code: String) -> String {
        if code.hasPrefix("zh") {
            return "zh-CN"
        }
        if code.hasPrefix("en") {
            return "en-US"
        }
        return "en-US"
    }
}
