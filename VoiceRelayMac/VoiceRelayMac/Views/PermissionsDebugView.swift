import SwiftUI

struct PermissionsDebugView: View {
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false
    @State private var debugInfo = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("权限调试")
                .font(.title)

            GroupBox(label: Text("权限状态")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(accessibilityGranted ? .green : .red)
                        Text("辅助功能")
                        Spacer()
                        Text(accessibilityGranted ? "已授予" : "未授予")
                    }

                    HStack {
                        Image(systemName: inputMonitoringGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(inputMonitoringGranted ? .green : .red)
                        Text("输入监控")
                        Spacer()
                        Text(inputMonitoringGranted ? "已授予" : "未授予")
                    }
                }
                .padding()
            }

            GroupBox(label: Text("应用信息")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")")
                        .font(.caption)
                    Text("应用路径: \(Bundle.main.bundlePath)")
                        .font(.caption)
                    Text("可执行文件: \(Bundle.main.executablePath ?? "未知")")
                        .font(.caption)
                }
                .padding()
            }

            if !debugInfo.isEmpty {
                GroupBox(label: Text("调试信息")) {
                    ScrollView {
                        Text(debugInfo)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .padding()
                }
            }

            VStack(spacing: 10) {
                Button("1️⃣ 检查权限") {
                    checkPermissions()
                }
                .buttonStyle(.bordered)

                Button("2️⃣ 请求辅助功能权限（会触发系统弹窗）") {
                    requestAccessibilityWithPrompt()
                }
                .buttonStyle(.borderedProminent)

                Button("3️⃣ 请求输入监控权限") {
                    requestInputMonitoring()
                }
                .buttonStyle(.borderedProminent)

                Button("4️⃣ 打开系统设置 - 辅助功能") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.bordered)

                Button("5️⃣ 打开系统设置 - 输入监控") {
                    openInputMonitoringSettings()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .frame(width: 600, height: 600)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)

        let inputStatus = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        inputMonitoringGranted = (inputStatus == kIOHIDAccessTypeGranted)

        debugInfo = """
        检查时间: \(Date())
        辅助功能: \(accessibilityGranted ? "✅" : "❌")
        输入监控: \(inputMonitoringGranted ? "✅" : "❌")
        输入监控状态码: \(inputStatus)
        """

        print("🔍 权限检查:")
        print("   辅助功能: \(accessibilityGranted ? "✅" : "❌")")
        print("   输入监控: \(inputMonitoringGranted ? "✅" : "❌")")
    }

    private func requestAccessibilityWithPrompt() {
        print("🔐 请求辅助功能权限（带提示）...")

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let result = AXIsProcessTrustedWithOptions(options)

        debugInfo += "\n\n请求辅助功能权限:"
        debugInfo += "\n时间: \(Date())"
        debugInfo += "\n结果: \(result ? "已授予" : "未授予")"
        debugInfo += "\n\n如果系统设置窗口打开了，请："
        debugInfo += "\n1. 在左侧找到「隐私与安全性」"
        debugInfo += "\n2. 点击「辅助功能」"
        debugInfo += "\n3. 在右侧列表中找到 VoiceMind"
        debugInfo += "\n4. 勾选启用"
        debugInfo += "\n\n⚠️ 如果看不到 VoiceMind："
        debugInfo += "\n• 点击左下角的「+」按钮"
        debugInfo += "\n• 导航到应用位置并添加"
        debugInfo += "\n• 应用路径: \(Bundle.main.bundlePath)"

        print("📝 请求结果: \(result ? "已授予" : "未授予")")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }

    private func requestInputMonitoring() {
        print("🔐 请求输入监控权限...")

        let result = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        debugInfo += "\n\n请求输入监控权限:"
        debugInfo += "\n时间: \(Date())"
        debugInfo += "\n结果: \(result ? "已授予" : "未授予")"

        print("📝 请求结果: \(result)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            debugInfo += "\n\n打开系统设置 - 辅助功能"
        }
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
            debugInfo += "\n\n打开系统设置 - 输入监控"
        }
    }
}

// Preview
#Preview {
    PermissionsDebugView()
}
