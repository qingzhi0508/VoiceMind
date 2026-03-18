import Foundation

extension UserDefaults {
    /// 选中的语音识别引擎
    var selectedSpeechEngine: String {
        get { string(forKey: "selectedEngine") ?? "apple-speech" }
        set { set(newValue, forKey: "selectedEngine") }
    }

    /// 是否自动下载模型
    var autoDownloadModels: Bool {
        get { bool(forKey: "autoDownloadModels") }
        set { set(newValue, forKey: "autoDownloadModels") }
    }

    /// 上次检查模型更新的时间
    var lastModelUpdateCheck: Date? {
        get { object(forKey: "lastModelUpdateCheck") as? Date }
        set { set(newValue, forKey: "lastModelUpdateCheck") }
    }
}
