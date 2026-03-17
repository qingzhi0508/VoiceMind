#!/bin/bash

# 语音识别能力测试脚本

echo "=== VoiceMind 语音识别能力测试 ==="
echo ""

# 检查 macOS 版本
echo "检查 macOS 版本..."
sw_vers

echo ""
echo "=== 测试说明 ==="
echo "1. 这个测试将验证 macOS Speech 框架是否可用"
echo "2. 测试将检查中文、英文等语言的支持情况"
echo "3. 测试将检查是否支持离线识别"
echo ""

# 创建临时 Swift 测试文件
cat > /tmp/speech_test.swift << 'EOF'
import Foundation
import Speech

print("=== macOS 语音识别能力测试 ===\n")

// 测试中文识别器
func testRecognizer(languageCode: String, languageName: String) {
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

// 测试不同语言
testRecognizer(languageCode: "zh-CN", languageName: "中文（简体）")
testRecognizer(languageCode: "en-US", languageName: "英文（美国）")
testRecognizer(languageCode: "zh-HK", languageName: "中文（粤语）")

// 请求权限
print("=== 请求语音识别权限 ===")
let semaphore = DispatchSemaphore(value: 0)

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
    semaphore.signal()
}

semaphore.wait()

print("\n=== 系统信息 ===")
print("macOS 版本: \(ProcessInfo.processInfo.operatingSystemVersionString)")

if #available(macOS 13.0, *) {
    print("✅ 支持 macOS 13+ 的增强语音识别")
} else {
    print("⚠️ macOS 版本较旧，可能不支持最新的语音识别功能")
}

print("\n=== 测试完成 ===")
print("如果所有测试都通过，说明可以使用 macOS Speech 框架进行本地语音识别")
EOF

# 编译并运行测试
echo "编译测试程序..."
swiftc /tmp/speech_test.swift -o /tmp/speech_test -framework Speech -framework Foundation

if [ $? -eq 0 ]; then
    echo "运行测试..."
    echo ""
    /tmp/speech_test

    # 清理
    rm /tmp/speech_test.swift
    rm /tmp/speech_test
else
    echo "❌ 编译失败"
    exit 1
fi
