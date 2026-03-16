import SwiftUI

struct PermissionsWindow: View {
    @State private var accessibilityGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Text("权限设置")
                .font(.title)

            VStack(alignment: .leading, spacing: 15) {
                PermissionRow(
                    title: "辅助功能",
                    description: "监听热键和注入文本所需",
                    isGranted: accessibilityGranted,
                    onRequest: {
                        PermissionsManager.requestAccessibility()
                        checkPermissions()
                    }
                )
            }
            .padding()

            Button("刷新") {
                checkPermissions()
            }
        }
        .frame(width: 500, height: 300)
        .padding()
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        accessibilityGranted = PermissionsManager.checkAccessibility() == .granted
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("授予权限") {
                    onRequest()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
