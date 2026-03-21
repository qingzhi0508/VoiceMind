import Foundation

enum AppLocalization {
    static func localizedString(
        _ key: String,
        languageCode: String = AppSettings.shared.language,
        bundle: Bundle = .main
    ) -> String {
        let localizedBundle = localizedBundle(for: languageCode, in: bundle)
        let localizedValue = localizedBundle.localizedString(forKey: key, value: nil, table: nil)

        if localizedValue != key {
            return localizedValue
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func bundleLocalizationCandidates(for languageCode: String) -> [String] {
        var candidates: [String] = []

        switch languageCode {
        case "zh-CN", "zh-Hans-CN", "zh-Hans":
            candidates.append("zh-Hans")
        case "zh-TW", "zh-Hant-TW", "zh-Hant":
            candidates.append("zh-Hant")
        default:
            break
        }

        candidates.append(languageCode)

        if let separatorIndex = languageCode.firstIndex(of: "-") {
            candidates.append(String(languageCode[..<separatorIndex]))
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func localizedBundle(for languageCode: String, in bundle: Bundle) -> Bundle {
        for candidate in bundleLocalizationCandidates(for: languageCode) {
            guard let path = bundle.path(forResource: candidate, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else {
                continue
            }

            return localizedBundle
        }

        return bundle
    }
}
