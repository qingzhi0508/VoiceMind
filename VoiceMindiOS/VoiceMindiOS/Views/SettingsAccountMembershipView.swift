import SwiftUI
import SharedCore

struct SettingsAccountMembershipView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        List {
            Section {
                accountSummaryCard
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)

            Section {
                billingButton(
                    title: billingTitle(for: .monthly),
                    isLoading: viewModel.isPurchasingTwoDeviceSync &&
                        viewModel.activeTwoDeviceSyncPurchaseProductID == TwoDeviceSyncProductKind.monthly.rawValue
                ) {
                    Task {
                        await viewModel.purchaseTwoDeviceSync(.monthly)
                    }
                }

                billingButton(
                    title: billingTitle(for: .yearly),
                    isLoading: viewModel.isPurchasingTwoDeviceSync &&
                        viewModel.activeTwoDeviceSyncPurchaseProductID == TwoDeviceSyncProductKind.yearly.rawValue
                ) {
                    Task {
                        await viewModel.purchaseTwoDeviceSync(.yearly)
                    }
                }

                billingButton(
                    title: billingTitle(for: .lifetime),
                    isLoading: viewModel.isPurchasingTwoDeviceSync &&
                        viewModel.activeTwoDeviceSyncPurchaseProductID == TwoDeviceSyncProductKind.lifetime.rawValue
                ) {
                    Task {
                        await viewModel.purchaseTwoDeviceSync(.lifetime)
                    }
                }

                billingButton(
                    title: String(localized: "billing_two_device_sync_restore_button"),
                    isLoading: viewModel.isRestoringTwoDeviceSyncPurchases
                ) {
                    Task {
                        await viewModel.restoreTwoDeviceSyncPurchases()
                    }
                }

                if let purchaseErrorMessage = viewModel.purchaseErrorMessage, !purchaseErrorMessage.isEmpty {
                    Text(purchaseErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(String(localized: "billing_two_device_sync_header"))
            } footer: {
                Text(String(localized: "billing_two_device_sync_footer"))
            }
        }
        .navigationTitle(String(localized: .init(SettingsMembershipPresentationPolicy.accountDestinationTitleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshTwoDeviceSyncBillingState()
        }
    }

    private var accountSummaryCard: some View {
        let presentation = SettingsMembershipPresentationPolicy.headerPresentation(
            for: viewModel.activeTwoDeviceSyncEntitlement
        )

        return SettingsAccountStatusCard(
            presentation: presentation,
            title: String(localized: .init(SettingsMembershipPresentationPolicy.rootHeaderTitleKey)),
            subtitle: viewModel.twoDeviceSyncStatusText,
            detail: viewModel.twoDeviceSyncDetailText
        )
    }

    private func billingTitle(for kind: TwoDeviceSyncProductKind) -> String {
        let prices = viewModel.twoDeviceSyncProducts
        if let price = prices[kind.rawValue] {
            switch kind {
            case .monthly:
                return String(format: String(localized: "billing_two_device_sync_monthly_button"), price)
            case .yearly:
                return String(format: String(localized: "billing_two_device_sync_yearly_button"), price)
            case .lifetime:
                return String(format: String(localized: "billing_two_device_sync_lifetime_button"), price)
            }
        }

        switch kind {
        case .monthly:
            return String(localized: "billing_two_device_sync_monthly_fallback")
        case .yearly:
            return String(localized: "billing_two_device_sync_yearly_fallback")
        case .lifetime:
            return String(localized: "billing_two_device_sync_lifetime_fallback")
        }
    }

    private func billingButton(
        title: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                Text(title)
                Spacer()
            }
        }
        .disabled(viewModel.isPurchasingTwoDeviceSync || viewModel.isRestoringTwoDeviceSyncPurchases)
    }
}
