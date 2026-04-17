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

    // MARK: - Volcengine ASR Config

    /// 火山引擎 App ID (X-Api-App-Key)
    var volcengineAppId: String {
        get { string(forKey: "volcengineAppId") ?? "" }
        set { set(newValue, forKey: "volcengineAppId") }
    }

    /// 火山引擎 Access Key (X-Api-Access-Key)
    var volcengineAccessKey: String {
        get { string(forKey: "volcengineAccessKey") ?? "" }
        set { set(newValue, forKey: "volcengineAccessKey") }
    }

    /// 火山引擎 Resource ID (X-Api-Resource-Id)
    var volcengineResourceId: String {
        get { string(forKey: "volcengineResourceId") ?? "volc.bigasr.sauc.duration" }
        set { set(newValue, forKey: "volcengineResourceId") }
    }

    /// Qwen3-ASR 选择的模型大小
    var selectedQwen3AsrModelSize: String {
        get { string(forKey: "selectedQwen3AsrModelSize") ?? "0.6b" }
        set { set(newValue, forKey: "selectedQwen3AsrModelSize") }
    }
}
