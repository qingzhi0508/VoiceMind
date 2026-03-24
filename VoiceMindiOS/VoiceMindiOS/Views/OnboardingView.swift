import SwiftUI

private enum OnboardingPalette {
    static let pageBackgroundTop = Color(red: 0.91, green: 0.95, blue: 1.0)
    static let pageBackgroundMid = Color(red: 0.96, green: 0.98, blue: 1.0)
    static let pageBackgroundBottom = Color(red: 0.99, green: 0.995, blue: 1.0)
    static let primaryText = Color(red: 0.08, green: 0.12, blue: 0.20)
    static let secondaryText = Color(red: 0.33, green: 0.39, blue: 0.48)
    static let panelFill = Color.white.opacity(0.96)
    static let panelStroke = Color(red: 0.84, green: 0.89, blue: 0.98)
    static let subtleFill = Color(red: 0.92, green: 0.95, blue: 1.0)
}

struct OnboardingView: View {
    @State private var currentPage = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    OnboardingPalette.pageBackgroundTop,
                    OnboardingPalette.pageBackgroundMid,
                    OnboardingPalette.pageBackgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    BrandPromisePage()
                        .tag(0)

                    IPhoneFirstPage()
                        .tag(1)

                    MacCollaborationPage()
                        .tag(2)

                    StartNowPage(onStart: onComplete)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentPage)

                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.accentColor : Color.primary.opacity(0.14))
                                .frame(width: index == currentPage ? 26 : 8, height: 8)
                        }
                    }

                    HStack {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentPage -= 1
                                }
                            }) {
                                Text(String(localized: "onboarding_back"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(OnboardingPalette.secondaryText)
                            }
                        } else {
                            Color.clear.frame(width: 44, height: 24)
                        }

                        Spacer()

                        if currentPage < 3 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentPage += 1
                                }
                            }) {
                                Text(String(localized: "onboarding_next"))
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct BrandPromisePage: View {
    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    OnboardingBadge(text: String(localized: "onboarding_brand_badge"))
                    Spacer()
                }

                Image("WelcomeIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
                    .modifier(PulseAnimationModifier())

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding_welcome_title"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(OnboardingPalette.primaryText)

                    Text(String(localized: "onboarding_welcome_subtitle"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        FeatureRow(
                            icon: "waveform.badge.mic",
                            tint: Color(red: 0.18, green: 0.44, blue: 0.95),
                            title: String(localized: "onboarding_brand_point1_title"),
                            detail: String(localized: "onboarding_brand_point1_desc")
                        )

                        FeatureRow(
                            icon: "sparkles.rectangle.stack",
                            tint: Color(red: 0.05, green: 0.65, blue: 0.62),
                            title: String(localized: "onboarding_brand_point2_title"),
                            detail: String(localized: "onboarding_brand_point2_desc")
                        )

                        FeatureRow(
                            icon: "lock.shield",
                            tint: Color(red: 0.96, green: 0.53, blue: 0.23),
                            title: String(localized: "onboarding_brand_point3_title"),
                            detail: String(localized: "onboarding_brand_point3_desc")
                        )
                    }
                }
            }
        }
    }
}

struct IPhoneFirstPage: View {
    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    OnboardingBadge(text: String(localized: "onboarding_input_badge"))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding_how_it_works_title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text(String(localized: "onboarding_how_it_works_subtitle"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }

                GlassPanel {
                    HStack(alignment: .center, spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.12, green: 0.16, blue: 0.24),
                                            Color(red: 0.09, green: 0.32, blue: 0.78)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 132, height: 240)

                            VStack(spacing: 16) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 42))
                                    .foregroundStyle(Color(red: 0.90, green: 0.96, blue: 1.0))
                                    .modifier(FloatAnimationModifier())

                                Text(String(localized: "onboarding_input_visual"))
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(OnboardingPalette.primaryText.opacity(0.92))

                                HStack(spacing: 6) {
                                    Capsule().fill(.white.opacity(0.95)).frame(width: 18, height: 6)
                                    Capsule().fill(.white.opacity(0.45)).frame(width: 36, height: 6)
                                    Capsule().fill(.white.opacity(0.75)).frame(width: 24, height: 6)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            StepCallout(index: 1, text: String(localized: "onboarding_step1"))
                            StepCallout(index: 2, text: String(localized: "onboarding_step2"))
                            StepCallout(index: 3, text: String(localized: "onboarding_step3"))
                        }
                    }
                }

                HStack(spacing: 12) {
                    MetricChip(
                        icon: "mic.fill",
                        title: String(localized: "onboarding_input_chip1_title"),
                        value: String(localized: "onboarding_input_chip1_value")
                    )
                    MetricChip(
                        icon: "hand.tap.fill",
                        title: String(localized: "onboarding_input_chip2_title"),
                        value: String(localized: "onboarding_input_chip2_value")
                    )
                }
            }
        }
    }
}

struct MacCollaborationPage: View {
    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    OnboardingBadge(text: String(localized: "onboarding_collaboration_badge"))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding_pairing_title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text(String(localized: "onboarding_pairing_subtitle"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }

                GlassPanel {
                    VStack(spacing: 18) {
                        HStack(spacing: 20) {
                            DeviceNode(
                                systemName: "iphone.gen3",
                                title: String(localized: "onboarding_device_iphone"),
                                tint: Color(red: 0.15, green: 0.48, blue: 0.96)
                            )

                            CollaborationBridge()

                            DeviceNode(
                                systemName: "laptopcomputer",
                                title: String(localized: "onboarding_device_mac"),
                                tint: Color(red: 0.10, green: 0.72, blue: 0.60)
                            )
                        }

                        VStack(spacing: 12) {
                            PairingStepCard(
                                step: "1",
                                title: String(localized: "onboarding_pairing_step1_title"),
                                description: String(localized: "onboarding_pairing_step1_desc"),
                                icon: "macwindow.badge.plus",
                                iconColor: Color(red: 0.10, green: 0.72, blue: 0.60)
                            )

                            PairingStepCard(
                                step: "2",
                                title: String(localized: "onboarding_pairing_step2_title"),
                                description: String(localized: "onboarding_pairing_step2_desc"),
                                icon: "qrcode.viewfinder",
                                iconColor: Color(red: 0.15, green: 0.48, blue: 0.96)
                            )

                            PairingStepCard(
                                step: "3",
                                title: String(localized: "onboarding_pairing_step3_title"),
                                description: String(localized: "onboarding_pairing_step3_desc"),
                                icon: "checkmark.seal.fill",
                                iconColor: Color(red: 0.96, green: 0.53, blue: 0.23)
                            )
                        }
                    }
                }
            }
        }
    }
}

struct StartNowPage: View {
    let onStart: () -> Void

    @State private var showPulse = false

    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    OnboardingBadge(text: String(localized: "onboarding_ready_badge"))
                    Spacer()
                }

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 154, height: 154)
                        .scaleEffect(showPulse ? 1.0 : 0.86)

                    Circle()
                        .fill(Color.accentColor.opacity(0.26))
                        .frame(width: 106, height: 106)

                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity)
                .modifier(BounceAnimationModifier())

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "onboarding_ready_title"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text(String(localized: "onboarding_ready_subtitle"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        TipRow(text: String(localized: "onboarding_tip1"), icon: "iphone.gen3.radiowaves.left.and.right")
                        TipRow(text: String(localized: "onboarding_tip2"), icon: "desktopcomputer.and.arrow.down")
                    }
                }

                Button(action: onStart) {
                    Text(String(localized: "onboarding_start_using"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onStart) {
                    Text(String(localized: "onboarding_skip"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                showPulse = true
            }
        }
    }
}

struct OnboardingPageContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                content
                    .padding(.horizontal, 28)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.72, alignment: .top)
        }
    }
}

struct OnboardingBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(OnboardingPalette.subtleFill, in: Capsule())
    }
}

struct GlassPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(OnboardingPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(OnboardingPalette.panelStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)
    }
}

struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingPalette.secondaryText)
            }

            Spacer()
        }
    }
}

struct StepCallout: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 34, height: 34)

                Text("\(index)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingPalette.primaryText)

            Spacer()
        }
    }
}

struct MetricChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(OnboardingPalette.secondaryText)

            Text(value)
                .font(.headline)
                .foregroundStyle(OnboardingPalette.primaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OnboardingPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OnboardingPalette.panelStroke, lineWidth: 1)
        )
    }
}

struct DeviceNode: View {
    let systemName: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 88, height: 88)

                Image(systemName: systemName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingPalette.primaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CollaborationBridge: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 72, height: 6)
                .overlay(alignment: animate ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
                }

            Text(String(localized: "onboarding_collaboration_bridge"))
                .font(.caption.weight(.medium))
                .foregroundStyle(OnboardingPalette.secondaryText)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct PairingStepCard: View {
    let step: String
    let title: String
    let description: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 30, height: 30)

                Text(step)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(OnboardingPalette.primaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.headline)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingPalette.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingPalette.subtleFill)
        )
    }
}

struct TipRow: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(OnboardingPalette.secondaryText)

            Spacer()
        }
    }
}

struct PulseAnimationModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    scale = 1.04
                }
            }
    }
}

struct FloatAnimationModifier: ViewModifier {
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    offset = -8
                }
            }
    }
}

struct BounceAnimationModifier: ViewModifier {
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    offset = -4
                }
            }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
