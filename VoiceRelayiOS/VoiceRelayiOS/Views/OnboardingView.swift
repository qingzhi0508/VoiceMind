import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack {
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)

                    HowItWorksPage()
                        .tag(1)

                    PairingGuidePage()
                        .tag(2)

                    StartUsingPage(onStart: {
                        onComplete()
                    })
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page Indicator and Navigation
                VStack(spacing: 20) {
                    // Page Dots
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Navigation Buttons
                    HStack {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Text(String(localized: "onboarding_back"))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if currentPage < 3 {
                            Button(action: {
                                withAnimation {
                                    currentPage += 1
                                }
                            }) {
                                Text(String(localized: "onboarding_next"))
                                    .fontWeight(.semibold)
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

// MARK: - Page 1: Welcome

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Icon with Animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .modifier(PulseAnimationModifier())

            VStack(spacing: 16) {
                Text(String(localized: "onboarding_welcome_title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(String(localized: "onboarding_welcome_subtitle"))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 2: How It Works

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text(String(localized: "onboarding_how_it_works_title"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "onboarding_how_it_works_subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Animated Flow Diagram
            VStack(spacing: 20) {
                HStack(spacing: 30) {
                    // iPhone
                    DeviceIcon(systemName: "iphone.gen3", color: .blue, label: String(localized: "onboarding_device_iphone"))
                        .modifier(FloatAnimationModifier())

                    ArrowIcon()
                        .modifier(BounceAnimationModifier())

                    // Mac
                    DeviceIcon(systemName: "desktopcomputer", color: .gray, label: String(localized: "onboarding_device_mac"))
                        .modifier(FloatAnimationModifier(delay: 0.3))
                }

                // Flow Description
                VStack(spacing: 12) {
                    FlowStepRow(
                        number: 1,
                        text: String(localized: "onboarding_step1"),
                        icon: "mic.fill",
                        color: .red
                    )

                    FlowStepRow(
                        number: 2,
                        text: String(localized: "onboarding_step2"),
                        icon: "waveform",
                        color: .blue
                    )

                    FlowStepRow(
                        number: 3,
                        text: String(localized: "onboarding_step3"),
                        icon: "text.cursor",
                        color: .green
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(16)
                .padding(.horizontal)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 3: Pairing Guide

struct PairingGuidePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text(String(localized: "onboarding_pairing_title"))
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "onboarding_pairing_subtitle"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Pairing Steps
            VStack(spacing: 24) {
                PairingStepCard(
                    step: "1",
                    title: String(localized: "onboarding_pairing_step1_title"),
                    description: String(localized: "onboarding_pairing_step1_desc"),
                    icon: "desktopcomputer",
                    iconColor: .gray
                )

                PairingStepCard(
                    step: "2",
                    title: String(localized: "onboarding_pairing_step2_title"),
                    description: String(localized: "onboarding_pairing_step2_desc"),
                    icon: "qrcode.viewfinder",
                    iconColor: .blue
                )

                PairingStepCard(
                    step: "3",
                    title: String(localized: "onboarding_pairing_step3_title"),
                    description: String(localized: "onboarding_pairing_step3_desc"),
                    icon: "link.circle.fill",
                    iconColor: .green
                )
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 4: Start Using

struct StartUsingPage: View {
    let onStart: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Success Animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: showCheckmark ? "checkmark.circle.fill" : "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            .modifier(BounceAnimationModifier())

            VStack(spacing: 16) {
                Text(String(localized: "onboarding_ready_title"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(String(localized: "onboarding_ready_subtitle"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                TipRow(text: String(localized: "onboarding_tip1"))
                TipRow(text: String(localized: "onboarding_tip2"))
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 30)

            Spacer()

            // Start Button
            Button(action: onStart) {
                Text(String(localized: "onboarding_start_using"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 30)

            Button(action: onStart) {
                Text(String(localized: "onboarding_skip"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Supporting Views

struct DeviceIcon: View {
    let systemName: String
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 44))
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ArrowIcon: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        Image(systemName: "arrow.right")
            .font(.title)
            .foregroundColor(.blue)
            .offset(x: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = 10
                }
            }
    }
}

struct FlowStepRow: View {
    let number: Int
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            Text(text)
                .font(.subheadline)

            Spacer()
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
        HStack(alignment: .top, spacing: 16) {
            // Step Number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)

                Text(step)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                    Text(title)
                        .font(.headline)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct TipRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Animations

struct PulseAnimationModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.05
                }
            }
    }
}

struct FloatAnimationModifier: ViewModifier {
    var delay: Double = 0

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
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
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = -5
                }
            }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
