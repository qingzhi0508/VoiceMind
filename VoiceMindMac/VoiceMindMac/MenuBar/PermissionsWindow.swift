import SwiftUI

struct PermissionsWindow: View {
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "permissions_title"))
                .font(.title)

            VStack(alignment: .leading, spacing: 15) {
                PermissionRow(
                    title: String(localized: "permission_accessibility_title"),
                    description: String(localized: "permission_accessibility_desc"),
                    isGranted: accessibilityGranted,
                    onRequest: {
                        PermissionsManager.requestAccessibility()
                        checkPermissions()
                    }
                )

                PermissionRow(
                    title: String(localized: "permission_input_monitor_title"),
                    description: String(localized: "permission_input_monitor_desc"),
                    isGranted: inputMonitoringGranted,
                    onRequest: {
                        PermissionsManager.requestInputMonitoring()
                    }
                )
            }
            .padding()

            Button(String(localized: "refresh_button")) {
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
        inputMonitoringGranted = PermissionsManager.checkInputMonitoring() == .granted
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
                Button(String(localized: "grant_permission_button")) {
                    onRequest()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
