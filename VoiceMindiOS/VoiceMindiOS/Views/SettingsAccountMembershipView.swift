import SwiftUI
import SharedCore

struct SettingsAccountMembershipView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.openURL) private var openURL
    @State private var locallyPendingProductID: String?
    @State private var isLocallyRestoringPurchases = false
    @State private var selectedProductKind: TwoDeviceSyncProductKind = .monthly

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                accountSummaryCard

                if let validityText = viewModel.twoDeviceSyncValidityText {
                    membershipInfoCard(validityText: validityText)
                }

                benefitsCard
                plansCard
                primaryPurchaseCard
                legalCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationTitle(String(localized: .init(SettingsMembershipPresentationPolicy.accountDestinationTitleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(AppPageCanvas())
        .task {
            await viewModel.refreshTwoDeviceSyncBillingState()
            syncSelectedProductKind()
        }
        .onChange(of: viewModel.activeTwoDeviceSyncEntitlement) { _, _ in
            syncSelectedProductKind()
        }
        .onChange(of: availableProductIDs) { _, _ in
            syncSelectedProductKind()
        }
    }

    private var availableProductIDs: [String] {
        Array(viewModel.twoDeviceSyncProducts.keys)
    }

    private var visibleProductKinds: [TwoDeviceSyncProductKind] {
        SettingsMembershipPurchasePolicy.visibleProductKinds(
            for: viewModel.activeTwoDeviceSyncEntitlement,
            availableProductIDs: availableProductIDs
        )
    }

    private var accountSummaryCard: some View {
        let presentation = SettingsMembershipPresentationPolicy.headerPresentation(
            for: viewModel.activeTwoDeviceSyncEntitlement
        )

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "billing_two_device_sync_header"))
                        .font(.title2.weight(.bold))

                    Text(viewModel.twoDeviceSyncStatusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !viewModel.twoDeviceSyncDetailText.isEmpty {
                        let detail = viewModel.twoDeviceSyncDetailText
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                membershipBadge(for: presentation)
            }

            if viewModel.activeTwoDeviceSyncEntitlement == .free {
                Text(String(localized: "billing_two_device_sync_footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .modifier(AppCardSurface())
    }

    private func membershipInfoCard(validityText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "billing_membership_status_title"))
                .font(.headline)

            HStack {
                Text(String(localized: "billing_two_device_sync_current_plan"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(planTitle(for: viewModel.activeTwoDeviceSyncEntitlement))
                    .fontWeight(.semibold)
            }

            HStack {
                Text(String(localized: "billing_two_device_sync_validity_label"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(validityText)
                    .fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .padding(18)
        .modifier(AppCardSurface())
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "billing_membership_benefits_title"))
                .font(.headline)

            ForEach(SettingsMembershipPresentationPolicy.benefitTitleKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.purple)
                        .padding(.top, 1)

                    Text(String(localized: .init(key)))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(18)
        .modifier(AppCardSurface())
    }

    private var plansCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "billing_membership_plans_title"))
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                ForEach(visibleProductKinds, id: \.rawValue) { kind in
                    planOptionCard(for: kind)
                }
            }
        }
        .padding(18)
        .modifier(AppCardSurface())
    }

    private func planOptionCard(for kind: TwoDeviceSyncProductKind) -> some View {
        let isSelected = selectedProductKind == kind
        let isOwned = SettingsMembershipPurchasePolicy.ownedProductKind(for: viewModel.activeTwoDeviceSyncEntitlement) == kind

        return Button {
            selectedProductKind = kind
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let badgeKey = badgeTitleKey(for: kind) {
                        Text(String(localized: .init(badgeKey)))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(badgeColor(for: kind).opacity(0.18))
                            )
                            .foregroundStyle(badgeColor(for: kind))
                    } else {
                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                Text(String(localized: .init(planTitleKey(for: kind))))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(String(localized: .init(planSubtitleKey(for: kind))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(planPrice(for: kind))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                if isOwned {
                    Text(String(localized: "billing_membership_current_plan_badge"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else if isSelected {
                    Text(String(localized: "billing_membership_selected_plan_badge"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.purple)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardFillColor(isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardBorderColor(isSelected: isSelected, isOwned: isOwned), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.purple.opacity(0.16) : Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var primaryPurchaseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "billing_membership_purchase_title"))
                .font(.headline)

            Button {
                purchase(selectedProductKind)
            } label: {
                HStack(spacing: 10) {
                    if purchaseLoadingState(for: selectedProductKind) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }

                    Text(primaryCTA)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .background(
                    LinearGradient(
                        colors: purchaseDisabledState(for: selectedProductKind)
                            ? [Color.gray.opacity(0.7), Color.gray.opacity(0.55)]
                            : [Color(red: 0.82, green: 0.23, blue: 0.95), Color(red: 0.56, green: 0.20, blue: 0.96)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(purchaseDisabledState(for: selectedProductKind))

            Text(autoRenewDescription(for: selectedProductKind))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let purchaseErrorMessage = viewModel.purchaseErrorMessage, !purchaseErrorMessage.isEmpty {
                Text(purchaseErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .modifier(AppCardSurface())
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                footerLinkButton(title: String(localized: "billing_two_device_sync_restore_button")) {
                    restorePurchases()
                }
                .disabled(restoreDisabledState)

                footerLinkButton(title: String(localized: "settings_privacy_policy")) {
                    openPrivacyPolicy()
                }

                footerLinkButton(title: String(localized: "settings_terms_of_use")) {
                    openTermsOfUse()
                }
            }
            .font(.footnote)

            Text(String(localized: "billing_membership_legal_notice"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .modifier(AppCardSurface())
    }

    private func footerLinkButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private func membershipBadge(for presentation: SettingsMembershipPresentationPolicy.HeaderPresentation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: presentation == .memberUser ? "sparkles" : "bolt.circle")
                .font(.system(size: 15, weight: .semibold))

            Text(
                String(
                    localized: presentation == .memberUser
                        ? "billing_membership_member_badge"
                        : "billing_membership_free_badge"
                )
            )
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill((presentation == .memberUser ? Color.purple : Color.blue).opacity(0.12))
        )
        .foregroundStyle(presentation == .memberUser ? .purple : .blue)
    }

    private func planTitle(for entitlement: TwoDeviceSyncEntitlement) -> String {
        switch entitlement {
        case .free:
            return String(localized: "billing_membership_plan_free_title")
        case .monthly:
            return String(localized: "billing_membership_plan_monthly_title")
        case .yearly:
            return String(localized: "billing_membership_plan_yearly_title")
        case .lifetime:
            return String(localized: "billing_membership_plan_lifetime_title")
        }
    }

    private func planTitleKey(for kind: TwoDeviceSyncProductKind) -> String {
        switch kind {
        case .monthly:
            return "billing_membership_plan_monthly_title"
        case .yearly:
            return "billing_membership_plan_yearly_title"
        case .lifetime:
            return "billing_membership_plan_lifetime_title"
        }
    }

    private func planSubtitleKey(for kind: TwoDeviceSyncProductKind) -> String {
        switch kind {
        case .monthly:
            return "billing_membership_plan_monthly_subtitle"
        case .yearly:
            return "billing_membership_plan_yearly_subtitle"
        case .lifetime:
            return "billing_membership_plan_lifetime_subtitle"
        }
    }

    private func badgeTitleKey(for kind: TwoDeviceSyncProductKind) -> String? {
        switch kind {
        case .monthly:
            return nil
        case .yearly:
            return "billing_membership_badge_best_value"
        case .lifetime:
            return "billing_membership_badge_save_more"
        }
    }

    private func badgeColor(for kind: TwoDeviceSyncProductKind) -> Color {
        switch kind {
        case .monthly:
            return .secondary
        case .yearly:
            return .blue
        case .lifetime:
            return .orange
        }
    }

    private func planPrice(for kind: TwoDeviceSyncProductKind) -> String {
        if let price = viewModel.twoDeviceSyncProducts[kind.rawValue] {
            return price
        }

        return String(localized: .init(fallbackTitleKey(for: kind)))
    }

    private func fallbackTitleKey(for kind: TwoDeviceSyncProductKind) -> String {
        switch kind {
        case .monthly:
            return "billing_two_device_sync_monthly_fallback"
        case .yearly:
            return "billing_two_device_sync_yearly_fallback"
        case .lifetime:
            return "billing_two_device_sync_lifetime_fallback"
        }
    }

    private var primaryCTA: String {
        if SettingsMembershipPurchasePolicy.ownedProductKind(for: viewModel.activeTwoDeviceSyncEntitlement) == selectedProductKind {
            return String(localized: "billing_membership_current_plan_cta")
        }

        return String(
            format: String(localized: "billing_membership_purchase_cta_format"),
            planPrice(for: selectedProductKind)
        )
    }

    private func autoRenewDescription(for kind: TwoDeviceSyncProductKind) -> String {
        switch kind {
        case .monthly:
            return String(localized: "billing_membership_auto_renew_monthly")
        case .yearly:
            return String(localized: "billing_membership_auto_renew_yearly")
        case .lifetime:
            return String(localized: "billing_membership_auto_renew_lifetime")
        }
    }

    private func cardFillColor(isSelected: Bool) -> Color {
        isSelected ? Color.purple.opacity(0.10) : Color.primary.opacity(0.04)
    }

    private func cardBorderColor(isSelected: Bool, isOwned: Bool) -> Color {
        if isOwned {
            return .green.opacity(0.65)
        }

        return isSelected ? .purple.opacity(0.85) : .white.opacity(0.18)
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

    private func syncSelectedProductKind() {
        let defaultKind = SettingsMembershipPurchasePolicy.defaultSelectedProductKind(
            activeEntitlement: viewModel.activeTwoDeviceSyncEntitlement,
            availableProductIDs: availableProductIDs
        )

        guard visibleProductKinds.contains(selectedProductKind) else {
            selectedProductKind = defaultKind
            return
        }

        if SettingsMembershipPurchasePolicy.ownedProductKind(for: viewModel.activeTwoDeviceSyncEntitlement) != nil {
            selectedProductKind = defaultKind
        }
    }

    private func purchase(_ kind: TwoDeviceSyncProductKind) {
        guard !purchaseDisabledState(for: kind) else { return }
        locallyPendingProductID = kind.rawValue

        Task {
            await viewModel.purchaseTwoDeviceSync(kind)
            await MainActor.run {
                locallyPendingProductID = nil
                syncSelectedProductKind()
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
                syncSelectedProductKind()
            }
        }
    }

    private func openTermsOfUse() {
        guard let url = SettingsMembershipLinkPolicy.termsOfUseURL else { return }
        openURL(url)
    }

    private func openPrivacyPolicy() {
        guard let url = SettingsMembershipLinkPolicy.privacyPolicyURL else { return }
        openURL(url)
    }
}
