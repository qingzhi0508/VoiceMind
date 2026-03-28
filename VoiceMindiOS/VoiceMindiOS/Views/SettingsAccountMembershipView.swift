import SwiftUI
import SharedCore

struct SettingsAccountMembershipView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var locallyPendingProductID: String?
    @State private var isLocallyRestoringPurchases = false

    var body: some View {
        List {
            Section {
                accountSummaryCard
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .modifier(AppGroupedRowSurface())

            if let validityText = viewModel.twoDeviceSyncValidityText {
                Section {
                    HStack {
                        Text(String(localized: "billing_two_device_sync_validity_label"))
                        Spacer()
                        Text(validityText)
                            .foregroundStyle(.secondary)
                    }
                }
                .modifier(AppGroupedRowSurface())
            }

            Section {
                ForEach(
                    SettingsMembershipPurchasePolicy.visibleProductKinds(
                        for: viewModel.activeTwoDeviceSyncEntitlement,
                        availableProductIDs: Array(viewModel.twoDeviceSyncProducts.keys)
                    ),
                    id: \.rawValue
                ) { kind in
                    billingButton(
                        title: billingTitle(for: kind),
                        isLoading: purchaseLoadingState(for: kind),
                        isDisabled: purchaseDisabledState(for: kind)
                    ) {
                        purchase(kind)
                    }
                }

                billingButton(
                    title: String(localized: "billing_two_device_sync_restore_button"),
                    isLoading: viewModel.isRestoringTwoDeviceSyncPurchases || isLocallyRestoringPurchases,
                    isDisabled: restoreDisabledState
                ) {
                    restorePurchases()
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
            .modifier(AppGroupedRowSurface())
        }
        .modifier(AppListChrome())
        .navigationTitle(String(localized: .init(SettingsMembershipPresentationPolicy.accountDestinationTitleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(AppPageCanvas())
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
        if let ownedTitleKey = SettingsMembershipPurchasePolicy.buttonTitleKey(
            for: kind,
            activeEntitlement: viewModel.activeTwoDeviceSyncEntitlement
        ) {
            return String(localized: .init(ownedTitleKey))
        }

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
        isDisabled: Bool,
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
        .disabled(isDisabled)
    }

    private func purchaseLoadingState(for kind: TwoDeviceSyncProductKind) -> Bool {
        viewModel.activeTwoDeviceSyncPurchaseProductID == kind.rawValue ||
        locallyPendingProductID == kind.rawValue
    }

    private func purchaseDisabledState(for kind: TwoDeviceSyncProductKind) -> Bool {
        SettingsMembershipPurchasePolicy.isPurchaseDisabled(
            productKind: kind,
            activeEntitlement: viewModel.activeTwoDeviceSyncEntitlement,
            activePurchaseProductID: viewModel.activeTwoDeviceSyncPurchaseProductID,
            locallyPendingProductID: locallyPendingProductID,
            isRestoringPurchases: viewModel.isRestoringTwoDeviceSyncPurchases || isLocallyRestoringPurchases
        )
    }

    private var restoreDisabledState: Bool {
        SettingsMembershipPurchasePolicy.isRestoreDisabled(
            activePurchaseProductID: viewModel.activeTwoDeviceSyncPurchaseProductID,
            locallyPendingProductID: locallyPendingProductID,
            isRestoringPurchases: viewModel.isRestoringTwoDeviceSyncPurchases,
            isLocallyRestoringPurchases: isLocallyRestoringPurchases
        )
    }

    private func purchase(_ kind: TwoDeviceSyncProductKind) {
        guard !purchaseDisabledState(for: kind) else { return }
        locallyPendingProductID = kind.rawValue

        Task {
            await viewModel.purchaseTwoDeviceSync(kind)
            await MainActor.run {
                locallyPendingProductID = nil
            }
        }
    }

    private func restorePurchases() {
        guard !restoreDisabledState else { return }
        isLocallyRestoringPurchases = true

        Task {
            await viewModel.restoreTwoDeviceSyncPurchases()
            await MainActor.run {
                isLocallyRestoringPurchases = false
            }
        }
    }
}
