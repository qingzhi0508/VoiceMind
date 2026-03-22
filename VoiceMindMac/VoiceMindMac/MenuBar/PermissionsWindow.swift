import SwiftUI

struct PermissionsWindow: View {
    @State private var accessibilityGranted = false

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
            }
            .padding()

            Button(AppLocalization.localizedString("refresh_button")) {
                checkPermissions()
            }
        }
        .frame(width: 500, height: 220)
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
                Button(AppLocalization.localizedString("grant_permission_button")) {
                    onRequest()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
