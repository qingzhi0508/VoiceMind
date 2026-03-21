import Foundation
import Speech

/// 测试 macOS 语音识别能力
class SpeechRecognitionTest {

    static func testAvailability() {
        print("=== macOS 语音识别能力测试 ===\n")

        // 测试中文识别器
        testRecognizer(languageCode: "zh-CN", languageName: "中文（简体）")

        // 测试英文识别器
        testRecognizer(languageCode: "en-US", languageName: "英文（美国）")

        // 测试粤语识别器
        testRecognizer(languageCode: "zh-HK", languageName: "中文（粤语）")

        // 请求权限
        print("\n=== 请求语音识别权限 ===")
        SFSpeechRecognizer.requestAuthorization { status in
            print("权限状态: \(status.rawValue)")
            switch status {
            case .authorized:
                print("✅ 已授权")
            case .denied:
                print("❌ 被拒绝")
            case .restricted:
                print("❌ 受限")
            case .notDetermined:
                print("⚠️ 未确定")
            @unknown default:
                print("❌ 未知状态")
            }
        }

        // 等待权限请求完成
        sleep(2)
    }

    private static func testRecognizer(languageCode: String, languageName: String) {
        print("--- \(languageName) (\(languageCode)) ---")

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)) else {
            print("❌ 无法创建识别器")
            print("")
            return
        }

        print("✅ 识别器创建成功")
        print("   可用: \(recognizer.isAvailable)")
        print("   支持设备上识别: \(recognizer.supportsOnDeviceRecognition)")
        print("   语言: \(recognizer.locale.identifier)")

        print("")
    }

    static func testSystemInfo() {
        print("=== 系统信息 ===")
        print("macOS 版本: \(ProcessInfo.processInfo.operatingSystemVersionString)")

        // 检查是否支持 Neural Engine
        if #available(macOS 13.0, *) {
            print("✅ 支持 macOS 13+ 的增强语音识别")
        } else {
            print("⚠️ macOS 版本较旧，可能不支持最新的语音识别功能")
        }

        print("")
    }
}
