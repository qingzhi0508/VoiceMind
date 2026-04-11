import SwiftUI
import UIKit
import Foundation

enum ContentTab: Int, CaseIterable {
    case home
    case data
    case settings

    static let defaultTab: ContentTab = .home

    var titleKey: LocalizedStringResource {
        switch self {
        case .home:
            "tab_home_title"
        case .data:
            "tab_data_title"
        case .settings:
            "settings_title"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .data:
            "tray.full.fill"
        case .settings:
            "gearshape.fill"
        }
    }
}

enum PairingSuccessNavigationPolicy {
    static func destinationTab(currentTab: ContentTab, pairingState: PairingState) -> ContentTab {
        if case .paired = pairingState {
            return .home
        }

        return currentTab
    }
}

private enum AppPageLayout {
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 10
    static let bottomPadding: CGFloat = 6
}

enum HomePageLayoutPolicy {
    static func usesOuterPagePadding(for tab: ContentTab) -> Bool {
        false
    }
}

enum ThemedPrimaryTabPolicy {
    static func usesCanvasBackground(for tab: ContentTab) -> Bool {
        switch tab {
        case .home, .data, .settings:
            return true
        }
    }
}

enum AppBackgroundVisualStyle: Equatable {
    case mutedMistLight
    case skyPopLight
    case darkSystem
}

enum AppSurfaceVisualStyle: Equatable {
    case defaultLight
    case skyPopLight
    case darkSystem
}

private struct AppTintColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    static let white = AppTintColor(red: 1, green: 1, blue: 1)
    static let skyPopDefault = AppTintColor(red: 0x66 / 255.0, green: 0xBD / 255.0, blue: 0xC9 / 255.0)

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init?(hex: String?) {
        guard let hex else { return nil }
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    var hexString: String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255.0).rounded()),
            Int((green * 255.0).rounded()),
            Int((blue * 255.0).rounded())
        )
    }

    func mixed(with other: AppTintColor, amount: Double) -> AppTintColor {
        let clampedAmount = min(max(amount, 0), 1)
        let inverse = 1 - clampedAmount

        return AppTintColor(
            red: (red * inverse) + (other.red * clampedAmount),
            green: (green * inverse) + (other.green * clampedAmount),
            blue: (blue * inverse) + (other.blue * clampedAmount)
        )
    }

    func color(opacity: Double = 1) -> Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }
}

enum AppLightBackgroundTintPolicy {
    static let storageKey = "light_theme_background_hex"
    static let defaultHex = "#66BDC9"

    static func effectiveHex(
        appTheme: String,
        colorScheme: ColorScheme,
        storedHex: String?
    ) -> String? {
        guard AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) == .skyPopLight else {
            return nil
        }

        return normalizedHex(storedHex: storedHex)
    }

    static func normalizedHex(storedHex: String?) -> String {
        AppTintColor(hex: storedHex)?.hexString ?? defaultHex
    }

    static func color(storedHex: String?) -> Color {
        tint(storedHex: storedHex).color()
    }

    static func colorBinding(storedHex: Binding<String>) -> Binding<Color> {
        Binding(
            get: {
                color(storedHex: storedHex.wrappedValue)
            },
            set: { newColor in
                storedHex.wrappedValue = hex(from: newColor)
            }
        )
    }

    static func hex(from color: Color) -> String {
        hex(from: UIColor(color)) ?? defaultHex
    }

    fileprivate static func tint(storedHex: String?) -> AppTintColor {
        AppTintColor(hex: storedHex) ?? .skyPopDefault
    }

    private static func hex(from uiColor: UIColor) -> String? {
        let resolvedColor = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return AppTintColor(
            red: Double(red),
            green: Double(green),
            blue: Double(blue)
        ).hexString
    }
}

private enum AppSkyPopPalettePolicy {
    static func pageGradient(storedHex: String?) -> [Color] {
        let tint = AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
        return [
            tint.mixed(with: .white, amount: 0.52).color(),
            tint.mixed(with: .white, amount: 0.66).color(),
            tint.mixed(with: .white, amount: 0.82).color()
        ]
    }

    static func verticalGlow(storedHex: String?) -> [Color] {
        let tint = AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
        return [
            Color.white.opacity(0.20),
            Color.clear,
            tint.mixed(with: .white, amount: 0.42).color(opacity: 0.26)
        ]
    }

    static func mistFill(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.54)
            .color(opacity: 0.20)
    }

    static func canvasWash(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.32)
            .color(opacity: 0.12)
    }

    static func screenHighlight(storedHex: String?) -> [Color] {
        let tint = AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
        return [
            Color.white.opacity(0.12),
            tint.mixed(with: .white, amount: 0.78).color(opacity: 0.04)
        ]
    }

    static func coolBubble(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.18)
            .color(opacity: 0.24)
    }

    static func tabBarFill(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.58)
            .color(opacity: 0.96)
    }

    static func groupedRowBackground(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.87)
            .color(opacity: 0.76)
    }

    static func softPanelFill(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.85)
            .color(opacity: 0.72)
    }

    static func softPanelStroke(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.60)
            .color(opacity: 0.62)
    }

    static func bottomBarFill(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.83)
            .color(opacity: 0.84)
    }

    static func cardGradient(storedHex: String?) -> [Color] {
        let tint = AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
        return [
            tint.mixed(with: .white, amount: 0.80).color(opacity: 0.82),
            tint.mixed(with: .white, amount: 0.88).color(opacity: 0.80),
            tint.mixed(with: .white, amount: 0.92).color(opacity: 0.76)
        ]
    }

    static func cardBorder(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: .white, amount: 0.58)
            .color(opacity: 0.68)
    }

    static func cardShadow(storedHex: String?) -> Color {
        AppLightBackgroundTintPolicy.tint(storedHex: storedHex)
            .mixed(with: AppTintColor(red: 0.30, green: 0.40, blue: 0.50), amount: 0.26)
            .color(opacity: 0.12)
    }
}

enum AppChromeStylePolicy {
    static func barBackgroundHex(
        appTheme: String,
        colorScheme: ColorScheme,
        storedHex: String?
    ) -> String? {
        AppLightBackgroundTintPolicy.effectiveHex(
            appTheme: appTheme,
            colorScheme: colorScheme,
            storedHex: storedHex
        )
    }

    static func tabBarFill(
        appTheme: String,
        colorScheme: ColorScheme,
        storedHex: String?
    ) -> Color? {
        guard barBackgroundHex(
            appTheme: appTheme,
            colorScheme: colorScheme,
            storedHex: storedHex
        ) != nil else {
            return nil
        }

        return AppSkyPopPalettePolicy.tabBarFill(storedHex: storedHex)
    }
}

enum AppCanvasStylePolicy {
    static func backgroundHex(
        appTheme: String,
        colorScheme: ColorScheme,
        storedHex: String?
    ) -> String? {
        AppLightBackgroundTintPolicy.effectiveHex(
            appTheme: appTheme,
            colorScheme: colorScheme,
            storedHex: storedHex
        )
    }
}

enum AppSurfaceStylePolicy {
    static func visualStyle(appTheme: String, colorScheme: ColorScheme) -> AppSurfaceVisualStyle {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .mutedMistLight:
            return .defaultLight
        case .skyPopLight:
            return .skyPopLight
        case .darkSystem:
            return .darkSystem
        }
    }

    static func groupedRowBackground(appTheme: String, colorScheme: ColorScheme, lightBackgroundHex: String? = nil) -> Color {
        switch visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return Color(uiColor: .secondarySystemBackground)
        case .defaultLight:
            return Color(uiColor: .secondarySystemBackground)
        case .skyPopLight:
            return AppSkyPopPalettePolicy.groupedRowBackground(storedHex: lightBackgroundHex)
        }
    }

    static func softPanelFill(appTheme: String, colorScheme: ColorScheme, lightBackgroundHex: String? = nil) -> Color {
        switch visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return Color(uiColor: .secondarySystemBackground)
        case .defaultLight:
            return Color.gray.opacity(0.10)
        case .skyPopLight:
            return AppSkyPopPalettePolicy.softPanelFill(storedHex: lightBackgroundHex)
        }
    }

    static func softPanelStroke(appTheme: String, colorScheme: ColorScheme, lightBackgroundHex: String? = nil) -> Color {
        switch visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return Color.white.opacity(0.06)
        case .defaultLight:
            return Color.white.opacity(0.22)
        case .skyPopLight:
            return AppSkyPopPalettePolicy.softPanelStroke(storedHex: lightBackgroundHex)
        }
    }

    static func bottomBarFill(appTheme: String, colorScheme: ColorScheme, lightBackgroundHex: String? = nil) -> Color {
        switch visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return Color(uiColor: .secondarySystemBackground).opacity(0.96)
        case .defaultLight:
            return Color.white.opacity(0.90)
        case .skyPopLight:
            return AppSkyPopPalettePolicy.bottomBarFill(storedHex: lightBackgroundHex)
        }
    }
}

struct AppCardSurface: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return content
            .background(
                shape
                    .fill(cardBackground)
            )
            .overlay(
                shape
                    .stroke(cardBorder, lineWidth: 1)
            )
            .shadow(color: cardShadow, radius: 18, x: 0, y: 10)
    }

    private var cardBackground: AnyShapeStyle {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
        case .mutedMistLight:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.88),
                        Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .skyPopLight:
            return AnyShapeStyle(
                LinearGradient(
                    colors: AppSkyPopPalettePolicy.cardGradient(storedHex: lightThemeBackgroundHex),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var cardBorder: Color {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return Color.white.opacity(0.06)
        case .mutedMistLight:
            return Color.white.opacity(0.72)
        case .skyPopLight:
            return AppSkyPopPalettePolicy.cardBorder(storedHex: lightThemeBackgroundHex)
        }
    }

    private var cardShadow: Color {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return Color.black.opacity(0.18)
        case .mutedMistLight:
            return Color.black.opacity(0.08)
        case .skyPopLight:
            return AppSkyPopPalettePolicy.cardShadow(storedHex: lightThemeBackgroundHex)
        }
    }
}

enum PrimaryRecognitionLayoutPolicy {
    static func recognitionControlAlignment(showingTranscriptPreview: Bool) -> Alignment {
        .center
    }

    static func transcriptCardHorizontalPadding(showingTranscriptPreview: Bool) -> CGFloat {
        showingTranscriptPreview ? AppPageLayout.horizontalPadding : 0
    }
}

enum HomeModeTogglePlacementPolicy {
    static func shouldShowModeSelector(sendToMacEnabled: Bool) -> Bool {
        sendToMacEnabled
    }
}

struct HomeModeSelector: View {
    @Binding var selectedMode: HomeTranscriptionMode
    let isConnected: Bool

    private var label: String {
        switch selectedMode {
        case .local: return String(localized: "mode_local")
        case .mac: return String(localized: "mode_mac")
        case .microphone: return String(localized: "mode_microphone")
        }
    }

    var body: some View {
        Menu {
            Button { selectedMode = .local } label: {
                Label(String(localized: "mode_local"), systemImage: selectedMode == .local ? "checkmark" : "")
            }
            Button { selectedMode = .mac } label: {
                Label(String(localized: "mode_mac"), systemImage: selectedMode == .mac ? "checkmark" : "")
            }
            Button { selectedMode = .microphone } label: {
                Label(String(localized: "mode_microphone"), systemImage: selectedMode == .microphone ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .imageScale(.small)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct AppCanvasBackgroundLayer: View {
    let appTheme: String
    let lightBackgroundHex: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .mutedMistLight:
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.94, blue: 0.96),
                    Color(red: 0.88, green: 0.91, blue: 0.95),
                    Color(red: 0.92, green: 0.93, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .skyPopLight:
            ZStack {
                LinearGradient(
                    colors: AppSkyPopPalettePolicy.pageGradient(storedHex: lightBackgroundHex),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: AppSkyPopPalettePolicy.verticalGlow(storedHex: lightBackgroundHex),
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(AppSkyPopPalettePolicy.mistFill(storedHex: lightBackgroundHex))
                    .blur(radius: 72)

                Rectangle()
                    .fill(AppSkyPopPalettePolicy.canvasWash(storedHex: lightBackgroundHex))
            }
        case .darkSystem:
            LinearGradient(
                colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct AppListChrome: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(
                AppCanvasBackgroundLayer(
                    appTheme: appTheme,
                    lightBackgroundHex: lightThemeBackgroundHex
                )
            )
    }
}

struct AppGroupedRowSurface: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.listRowBackground(
            AppSurfaceStylePolicy.groupedRowBackground(
                appTheme: appTheme,
                colorScheme: colorScheme,
                lightBackgroundHex: lightThemeBackgroundHex
            )
        )
    }
}

struct AppTabBarChrome: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if let fill = AppChromeStylePolicy.tabBarFill(
            appTheme: appTheme,
            colorScheme: colorScheme,
            storedHex: lightThemeBackgroundHex
        ) {
            content
                .toolbarBackground(fill, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        } else {
            content
        }
    }
}

struct AppNavigationCanvas: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex

    func body(content: Content) -> some View {
        content
            .background(
                AppCanvasBackgroundLayer(
                    appTheme: appTheme,
                    lightBackgroundHex: lightThemeBackgroundHex
                )
                .ignoresSafeArea()
            )
    }
}

struct AppPageCanvas: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex

    func body(content: Content) -> some View {
        content.background(
            AppCanvasBackgroundLayer(
                appTheme: appTheme,
                lightBackgroundHex: lightThemeBackgroundHex
            )
            .ignoresSafeArea()
        )
    }
}

enum AppBackgroundStylePolicy {
    static func visualStyle(appTheme: String, colorScheme: ColorScheme) -> AppBackgroundVisualStyle {
        if colorScheme == .dark {
            return .darkSystem
        }

        if appTheme == "light" {
            return .skyPopLight
        }

        return .mutedMistLight
    }

    static func showsRainbowBubbles(appTheme: String, colorScheme: ColorScheme) -> Bool {
        switch visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem:
            return false
        case .mutedMistLight, .skyPopLight:
            return true
        }
    }

    static let usesModernGlassSurfaces = true
}

enum ContentInteractionPolicy {
    static func shouldDismissKeyboardOnBackgroundTap(isTranscriptEditorFocused: Bool) -> Bool {
        isTranscriptEditorFocused
    }
}

enum TranscriptTextViewSyncPolicy {
    static func shouldApplyExternalText(
        currentText: String,
        newText: String,
        isFirstResponder: Bool,
        hasMarkedText: Bool
    ) -> Bool {
        guard currentText != newText else { return false }
        if isFirstResponder && hasMarkedText {
            return false
        }
        return true
    }
}

enum TranscriptHistoryEditingPolicy {
    static func shouldAutoSaveOnBackgroundTap(isEditing: Bool) -> Bool {
        isEditing
    }

    static func savedText(originalText: String, draftText: String) -> String {
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDraft.isEmpty ? originalText : trimmedDraft
    }
}

enum RecognitionStatusInteractionPolicy {
    static func shouldShowManualSendTarget(
        isPressing: Bool,
        state: RecognitionState
    ) -> Bool {
        false
    }

    static func isInteractionEnabled(
        isEnabled: Bool,
        showsReconnectAction: Bool
    ) -> Bool {
        isEnabled || showsReconnectAction
    }
}

struct ContentView: View {
    enum FocusField: Hashable {
        case transcriptEditor
    }

    @StateObject private var viewModel = ContentViewModel()
    @Binding var hasLaunchedBefore: Bool

    @State private var showOnboarding = false
    @State private var selectedTab = ContentTab.defaultTab
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @FocusState private var focusedField: FocusField?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            backgroundLayer

            // Decorative Elements
            GeometryReader { geometry in
                ZStack {
                    if AppBackgroundStylePolicy.showsRainbowBubbles(
                        appTheme: appTheme,
                        colorScheme: colorScheme
                    ) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.00, green: 0.64, blue: 0.72).opacity(0.28),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 240
                                )
                            )
                            .frame(width: 360, height: 360)
                            .offset(x: geometry.size.width - 130, y: -40)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) == .skyPopLight
                                        ? AppSkyPopPalettePolicy.coolBubble(storedHex: lightThemeBackgroundHex)
                                        : Color(red: 0.48, green: 0.78, blue: 1.00).opacity(0.24),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 230
                                )
                            )
                            .frame(width: 330, height: 330)
                            .offset(x: -90, y: geometry.size.height - 210)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.93, green: 0.82, blue: 1.00).opacity(0.21),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .frame(width: 290, height: 290)
                            .offset(x: geometry.size.width * 0.14, y: geometry.size.height * 0.30)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.00, green: 0.88, blue: 0.45).opacity(0.16),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 180
                                )
                            )
                            .frame(width: 240, height: 240)
                            .offset(x: geometry.size.width * 0.62, y: geometry.size.height * 0.46)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard ContentInteractionPolicy.shouldDismissKeyboardOnBackgroundTap(
                        isTranscriptEditorFocused: focusedField == .transcriptEditor
                    ) else {
                        return
                    }
                    dismissKeyboard()
                }
            }

            TabView(selection: $selectedTab) {
                NavigationStack {
                    PrimaryRecognitionPage(
                        viewModel: viewModel,
                        isTranscriptFocused: Binding(
                            get: { focusedField == .transcriptEditor },
                            set: { focusedField = $0 ? .transcriptEditor : nil }
                        ),
                        onDismissKeyboard: dismissKeyboard
                    )
                    .modifier(
                        AppOuterPagePadding(
                            isEnabled: HomePageLayoutPolicy.usesOuterPagePadding(for: .home)
                        )
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
                .modifier(AppNavigationCanvas())
                .tabItem {
                    Label(String(localized: ContentTab.home.titleKey), systemImage: ContentTab.home.systemImage)
                }
                .tag(ContentTab.home)

                NavigationStack {
                    TranscriptHistoryPage(
                        canSendToMac: { record in
                            viewModel.canSendTranscriptRecordToMac(record)
                        },
                        onSendToMac: { record in
                            viewModel.sendTranscriptRecordToMac(record)
                        },
                        history: viewModel.localTranscriptHistory,
                        onDeleteSelected: { ids in
                            viewModel.removeLocalTranscriptRecords(ids: ids)
                        },
                        onDelete: { id in
                            viewModel.removeLocalTranscriptRecord(id: id)
                        },
                        onUpdate: { id, text in
                            viewModel.updateLocalTranscriptRecord(id: id, text: text)
                        },
                        onDismissKeyboard: dismissKeyboard
                    )
                    .modifier(
                        AppOuterPagePadding(
                            isEnabled: HomePageLayoutPolicy.usesOuterPagePadding(for: .data)
                        )
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
                .modifier(AppNavigationCanvas())
                .tabItem {
                    Label(String(localized: ContentTab.data.titleKey), systemImage: ContentTab.data.systemImage)
                }
                .tag(ContentTab.data)

                NavigationStack {
                    SettingsView(viewModel: viewModel, showsNavigationTitle: false)
                }
                .modifier(AppNavigationCanvas())
                .tabItem {
                    Label(String(localized: ContentTab.settings.titleKey), systemImage: ContentTab.settings.systemImage)
                }
                .tag(ContentTab.settings)
            }
            .modifier(AppTabBarChrome())
            .sheet(isPresented: $viewModel.showPairingView) {
                PairingView(viewModel: viewModel)
            }
            .onChange(of: viewModel.pairingState) { _, newValue in
                selectedTab = PairingSuccessNavigationPolicy.destinationTab(
                    currentTab: selectedTab,
                    pairingState: newValue
                )
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onComplete: {
                    showOnboarding = false
                    hasLaunchedBefore = true
                })
            }
            .onAppear {
                viewModel.preparePrimaryExperience()
                syncIdleTimerState()
                if !hasLaunchedBefore {
                    showOnboarding = true
                    hasLaunchedBefore = true
                }
            }
            .onDisappear {
                AppIdleTimerController.shared.setKeepsScreenAwake(false)
            }
            .onChange(of: selectedTab) { _, _ in
                dismissKeyboard()
                syncIdleTimerState()
            }
            .onChange(of: scenePhase) { _, _ in
                syncIdleTimerState()
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .mutedMistLight:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.94, blue: 0.96),
                        Color(red: 0.88, green: 0.91, blue: 0.95),
                        Color(red: 0.92, green: 0.93, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.56),
                        Color.clear,
                        Color(red: 0.86, green: 0.89, blue: 0.94).opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(Color.white.opacity(0.24))
                    .blur(radius: 90)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .ignoresSafeArea()
        case .skyPopLight:
            ZStack {
                LinearGradient(
                    colors: AppSkyPopPalettePolicy.pageGradient(storedHex: lightThemeBackgroundHex),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: AppSkyPopPalettePolicy.verticalGlow(storedHex: lightThemeBackgroundHex),
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(AppSkyPopPalettePolicy.mistFill(storedHex: lightThemeBackgroundHex))
                    .blur(radius: 72)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: AppSkyPopPalettePolicy.screenHighlight(storedHex: lightThemeBackgroundHex),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .ignoresSafeArea()
        case .darkSystem:
            LinearGradient(
                colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func syncIdleTimerState() {
        let shouldKeepScreenAwake = HomeIdleTimerPolicy.shouldKeepScreenAwake(
            selectedTab: selectedTab,
            scenePhase: scenePhase
        )
        AppIdleTimerController.shared.setKeepsScreenAwake(shouldKeepScreenAwake)
    }
}

struct AppOuterPagePadding: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .padding(.horizontal, AppPageLayout.horizontalPadding)
                .padding(.top, AppPageLayout.topPadding)
                .padding(.bottom, AppPageLayout.bottomPadding)
        } else {
            content
        }
    }
}

struct TranscriptCard: View {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @Environment(\.colorScheme) private var colorScheme
    @Binding var transcriptText: String
    @Binding var isFocused: Bool
    let autoScrollVersion: Int
    let isEditable: Bool
    let recognitionState: RecognitionState
    let liveStatusMessage: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            TranscriptTextView(
                text: $transcriptText,
                isFocused: $isFocused,
                autoScrollVersion: autoScrollVersion,
                isEditable: isEditable
            )
            .frame(height: 150)
            .padding(.leading, 8)
            .padding(.trailing, 8)

            if transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if recognitionState != .idle {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(liveStatusMessage ?? String(localized: "transcript_card_live_placeholder"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                        }
                    } else {
                        Text(String(localized: "transcript_card_placeholder"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 0)
                .padding(.leading, 8)
                .allowsHitTesting(false)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(transcriptCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(transcriptCardBorder, lineWidth: 1)
        )
        .shadow(color: transcriptCardShadow, radius: 18, x: 0, y: 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .clipped()
    }

    private var transcriptCardBackground: AnyShapeStyle {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem, .mutedMistLight:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(uiColor: .secondarySystemBackground),
                        Color(uiColor: .tertiarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .skyPopLight:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.76),
                        Color(red: 0.96, green: 0.98, blue: 1.00).opacity(0.74),
                        Color(red: 0.94, green: 0.97, blue: 1.00).opacity(0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var transcriptCardBorder: Color {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem, .mutedMistLight:
            return Color.white.opacity(0.55)
        case .skyPopLight:
            return Color.white.opacity(0.60)
        }
    }

    private var transcriptCardShadow: Color {
        switch AppBackgroundStylePolicy.visualStyle(appTheme: appTheme, colorScheme: colorScheme) {
        case .darkSystem, .mutedMistLight:
            return Color.black.opacity(0.06)
        case .skyPopLight:
            return Color(red: 0.35, green: 0.50, blue: 0.60).opacity(0.10)
        }
    }
}

struct VoiceIsolationTipBanner: View {
    @Binding var isDismissed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mic.badge.xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "voice_isolation_tip_title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(String(localized: "voice_isolation_tip_body"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeOut(duration: 0.25)) {
                    isDismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(4)
            }
            .contentShape(Rectangle())
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

struct TranscriptActionBar: View {
    let onConfirm: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onConfirm) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "transcript_action_confirm"))
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Capsule())
            }

            Button(action: onUndo) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "transcript_action_undo"))
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.secondary)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

struct PrimaryRecognitionPage: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isTranscriptFocused: Bool
    let onDismissKeyboard: () -> Void
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @AppStorage("voicemind.voiceIsolationTipDismissed") private var voiceIsolationTipDismissed: Bool = false
    @State private var showsMacActionAlert = false

    private var showsVoiceIsolationTip: Bool {
        !voiceIsolationTipDismissed
        && viewModel.effectiveHomeTranscriptionMode == .microphone
        && viewModel.recognitionState == .idle
        && viewModel.connectionState == .connected
    }

    var body: some View {
        VStack(spacing: 0) {
            if HomeModeTogglePlacementPolicy.shouldShowModeSelector(
                sendToMacEnabled: viewModel.sendResultsToMacEnabled
            ) {
                HomeModeSelector(
                    selectedMode: Binding(
                        get: { viewModel.preferredHomeTranscriptionMode },
                        set: { viewModel.setHomeTranscriptionMode($0) }
                    ),
                    isConnected: viewModel.connectionState == .connected
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

        ZStack(
            alignment: PrimaryRecognitionLayoutPolicy.recognitionControlAlignment(
                showingTranscriptPreview: viewModel.shouldShowTranscriptPreviewOnHome
            )
        ) {
            RecognitionStatusView(
                state: viewModel.recognitionState,
                statusMessage: viewModel.pushToTalkStatusMessage,
                isEnabled: viewModel.canStartPushToTalk || viewModel.recognitionState != .idle,
                showsPairingAction: false,
                showsReconnectAction: viewModel.shouldPromptForHomeMacAction,
                audioLevel: viewModel.audioLevel,
                onPressChanged: { isPressing in
                    if isPressing {
                        onDismissKeyboard()
                    }
                    viewModel.handlePrimaryButtonPressChanged(isPressing)
                },
                onReconnectAction: {
                    onDismissKeyboard()
                    showsMacActionAlert = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(spacing: 0) {
                if viewModel.shouldShowTranscriptPreviewOnHome {
                    TranscriptCard(
                        transcriptText: Binding(
                            get: { viewModel.localTranscriptText },
                            set: { viewModel.updateLocalTranscriptText($0) }
                        ),
                        isFocused: $isTranscriptFocused,
                        autoScrollVersion: viewModel.transcriptAutoScrollVersion,
                        isEditable: false,
                        recognitionState: viewModel.recognitionState,
                        liveStatusMessage: viewModel.pushToTalkStatusMessage
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.96, anchor: .top)),
                            removal: .opacity
                        )
                    )
                    .padding(
                        .horizontal,
                        PrimaryRecognitionLayoutPolicy.transcriptCardHorizontalPadding(
                            showingTranscriptPreview: viewModel.shouldShowTranscriptPreviewOnHome
                        )
                    )
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .overlay(alignment: .bottom) {
            if TranscriptActionBarPlacementPolicy.shouldShowBar(
                showsTranscriptActions: viewModel.showsTranscriptActions
            ) {
                GeometryReader { geo in
                    TranscriptActionBar(
                        onConfirm: { viewModel.confirmTranscriptAction() },
                        onUndo: { viewModel.undoTranscriptAction() }
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.72)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.showsTranscriptActions)
            }
        }

        .background(
            AppCanvasBackgroundLayer(
                appTheme: appTheme,
                lightBackgroundHex: lightThemeBackgroundHex
            )
            .ignoresSafeArea()
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: viewModel.shouldShowTranscriptPreviewOnHome)
        .alert(
            String(localized: "home_mac_action_alert_title"),
            isPresented: $showsMacActionAlert
        ) {
            Button(String(localized: "reconnect_button")) {
                viewModel.reconnect()
            }
            Button(String(localized: "home_mac_action_pair_button")) {
                viewModel.openPairing()
            }
            Button(String(localized: "cancel_button"), role: .cancel) {}
        } message: {
            Text(String(localized: "home_mac_action_alert_message"))
        }

        if showsVoiceIsolationTip {
            VoiceIsolationTipBanner(isDismissed: $voiceIsolationTipDismissed)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        }
    }
}

struct TranscriptHistoryPage: View {
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage(AppLightBackgroundTintPolicy.storageKey) private var lightThemeBackgroundHex: String = AppLightBackgroundTintPolicy.defaultHex
    @Environment(\.colorScheme) private var colorScheme
    let canSendToMac: (LocalTranscriptRecord) -> Bool
    let onSendToMac: (LocalTranscriptRecord) -> Void
    let history: [LocalTranscriptRecord]
    let onDeleteSelected: (Set<UUID>) -> Void
    let onDelete: (UUID) -> Void
    let onUpdate: (UUID, String) -> Void
    let onDismissKeyboard: () -> Void
    @State private var editingRecordID: UUID?
    @State private var draftText = ""
    @State private var isEditingFocused = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedRecordIDs = Set<UUID>()
    @State private var showsBatchDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !history.isEmpty {
                historyActionsBar
            }

            if history.isEmpty {
                emptyHistoryView
            } else {
                historyListView
            }

            Text(String(localized: "transcript_history_swipe_hint"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, AppPageLayout.horizontalPadding)

            if editMode == .active {
                batchDeleteBar
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard TranscriptHistoryEditingPolicy.shouldAutoSaveOnBackgroundTap(
                        isEditing: editingRecordID != nil
                    ) else {
                        return
                    }
                    saveEditingIfNeeded()
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(
            String(localized: "transcript_history_batch_delete_title"),
            isPresented: $showsBatchDeleteConfirmation
        ) {
            Button(String(localized: "delete_button"), role: .destructive) {
                deleteSelectedRecords()
            }
            Button(String(localized: "cancel_button"), role: .cancel) {}
        } message: {
            Text(batchDeleteConfirmationMessage)
        }
        .onChange(of: editMode) { _, newValue in
            if newValue != .active {
                selectedRecordIDs.removeAll()
            }
        }
        .onDisappear {
            saveEditingIfNeeded()
        }
        .modifier(AppPageCanvas())
    }

    private var emptyHistoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "transcript_history_empty_title"))
                .font(.body)
                .foregroundColor(.primary)
            Text(String(localized: "transcript_history_empty_hint"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, AppPageLayout.horizontalPadding)
        .padding(.top, 12)
    }

    private var historyListView: some View {
        List(selection: $selectedRecordIDs) {
            ForEach(history) { record in
                historyRow(for: record)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .contentMargins(.top, 0, for: .scrollContent)
        .simultaneousGesture(
            TapGesture().onEnded {
                onDismissKeyboard()
            }
        )
        .environment(\.editMode, $editMode)
    }

    @ViewBuilder
    private func historyRow(for record: LocalTranscriptRecord) -> some View {
        if editingRecordID == record.id {
            EditableTranscriptHistoryRow(
                text: $draftText,
                isFocused: $isEditingFocused
            )
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .listRowBackground(
                AppSurfaceStylePolicy.groupedRowBackground(
                    appTheme: appTheme,
                    colorScheme: colorScheme,
                    lightBackgroundHex: lightThemeBackgroundHex
                )
            )
        } else {
            TranscriptHistoryRow(record: record)
                .tag(record.id)
                .contentShape(Rectangle())
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .listRowBackground(
                    AppSurfaceStylePolicy.groupedRowBackground(
                        appTheme: appTheme,
                        colorScheme: colorScheme,
                        lightBackgroundHex: lightThemeBackgroundHex
                    )
                )
                .swipeActions(
                    edge: TranscriptHistorySendPolicy.swipeEdge,
                    allowsFullSwipe: TranscriptHistorySendPolicy.allowsFullSwipe
                ) {
                    if shouldShowSendAction(for: record) {
                        Button {
                            onSendToMac(record)
                        } label: {
                            Label(String(localized: "send_button"), systemImage: "paperplane.fill")
                        }
                        .tint(.blue)
                    }
                }
                .swipeActions(
                    edge: TranscriptHistoryDeletePolicy.swipeEdge,
                    allowsFullSwipe: TranscriptHistoryDeletePolicy.allowsFullSwipe
                ) {
                    if shouldShowDeleteAction {
                        Button(role: .destructive) {
                            onDelete(record.id)
                        } label: {
                            Text(String(localized: "delete_button"))
                        }
                    }
                }
                .onTapGesture(count: 2) {
                    guard editMode != .active else { return }
                    saveEditingIfNeeded()
                    beginEditing(record)
                }
                .onTapGesture {
                    guard editMode != .active else { return }
                    handleNonEditingRowTap()
                }
        }
    }

    private var historyActionsBar: some View {
        HStack(spacing: 12) {
            if editMode == .active {
                Button(String(localized: "select_all_button")) {
                    toggleSelectAll()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.blue)
            }

            Spacer()

            Button(editMode == .active ? String(localized: "done_button") : String(localized: "edit_button")) {
                toggleEditMode()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
        }
        .padding(.horizontal, AppPageLayout.horizontalPadding)
    }

    private var batchDeleteBar: some View {
        Button(role: .destructive) {
            guard canDeleteSelectedRecords else {
                return
            }
            showsBatchDeleteConfirmation = true
        } label: {
            Text(batchDeleteButtonTitle)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(!canDeleteSelectedRecords)
        .padding(.horizontal, AppPageLayout.horizontalPadding)
    }

    private func beginEditing(_ record: LocalTranscriptRecord) {
        editingRecordID = record.id
        draftText = record.text
        isEditingFocused = true
    }

    private func handleNonEditingRowTap() {
        guard editingRecordID != nil else { return }
        saveEditingIfNeeded()
    }

    private func saveEditingIfNeeded() {
        guard let editingRecordID else { return }
        guard let record = history.first(where: { $0.id == editingRecordID }) else {
            clearEditingState()
            return
        }

        let savedText = TranscriptHistoryEditingPolicy.savedText(
            originalText: record.text,
            draftText: draftText
        )
        if savedText != record.text {
            onUpdate(editingRecordID, savedText)
        }
        clearEditingState()
    }

    private func clearEditingState() {
        editingRecordID = nil
        draftText = ""
        isEditingFocused = false
    }

    private func toggleEditMode() {
        saveEditingIfNeeded()
        editMode = editMode == .active ? .inactive : .active
    }

    private func toggleSelectAll() {
        if selectedRecordIDs.count == history.count {
            selectedRecordIDs.removeAll()
        } else {
            selectedRecordIDs = Set(history.map(\.id))
        }
    }

    private func deleteSelectedRecords() {
        let ids = selectedRecordIDs
        guard !ids.isEmpty else { return }
        onDeleteSelected(ids)
        selectedRecordIDs.removeAll()
        editMode = .inactive
    }

    private var selectedRecordIDStrings: [String] {
        selectedRecordIDs.map(\.uuidString)
    }

    private var selectedDeleteCount: Int {
        TranscriptHistoryBatchDeletePolicy.selectedDeleteCount(
            selectedRecordIDs: selectedRecordIDStrings
        )
    }

    private var canDeleteSelectedRecords: Bool {
        TranscriptHistoryBatchDeletePolicy.canDeleteSelectedRecords(
            selectedRecordIDs: selectedRecordIDStrings
        )
    }

    private var batchDeleteButtonTitle: String {
        String(
            format: String(localized: "transcript_history_delete_selected_format"),
            selectedDeleteCount
        )
    }

    private var batchDeleteConfirmationMessage: String {
        String(
            format: String(localized: "transcript_history_batch_delete_message_format"),
            selectedDeleteCount
        )
    }

    private var shouldShowDeleteAction: Bool {
        editMode != .active
    }

    private func shouldShowSendAction(for record: LocalTranscriptRecord) -> Bool {
        editMode != .active && canSendToMac(record)
    }
}

enum TranscriptHistoryDeletePolicy {
    static let swipeEdge: HorizontalEdge = .trailing
    static let usesTrailingSwipe = true
    static let allowsFullSwipe = true
    static let requiresConfirmation = false
}

enum TranscriptHistorySendPolicy {
    static let swipeEdge: HorizontalEdge = .leading
    static let usesLeadingSwipe = true
    static let allowsFullSwipe = false
}

enum TranscriptHistoryBatchDeletePolicy {
    static func canDeleteSelectedRecords(selectedRecordIDs: [String]) -> Bool {
        !selectedRecordIDs.isEmpty
    }

    static func selectedDeleteCount(selectedRecordIDs: [String]) -> Int {
        selectedRecordIDs.count
    }
}

enum TranscriptHistoryEmptyStateLayoutPolicy {
    static let usesCardSurface = false
}

struct TranscriptHistoryRow: View {
    let record: LocalTranscriptRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.text)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = record.text
                    } label: {
                        Label(String(localized: "copy_button"), systemImage: "doc.on.doc")
                    }
                }

            Text(record.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EditableTranscriptHistoryRow: View {
    @Binding var text: String
    @Binding var isFocused: Bool

    var body: some View {
        TranscriptTextView(
            text: $text,
            isFocused: $isFocused,
            autoScrollVersion: 0,
            isEditable: true
        )
        .frame(minHeight: 132)
        .padding(.vertical, 4)
    }
}

struct ConnectionStatusCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState
    let reconnectStatusMessage: String?
    let onReconnect: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.headline)

                Spacer()

                // 显示重连按钮（仅在已配对但断开连接时）
                if case .paired = pairingState,
                   case .disconnected = connectionState {
                    Button(action: onReconnect) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "reconnect_button"))
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // 显示加载指示器（连接中）
                if case .connecting = connectionState {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case .paired(_, let deviceName) = pairingState {
                HStack {
                    Text(String(format: String(localized: "paired_device_format"), deviceName))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // 显示错误信息
            if case .error(let message) = connectionState {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            if let reconnectStatusMessage,
               case .paired = pairingState {
                HStack(alignment: .top) {
                    Image(systemName: reconnectStatusIcon)
                        .foregroundColor(reconnectStatusColor)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(reconnectStatusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .modifier(AppCardSurface())
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return .gray
        case (.paired, .connected):
            return .green
        case (.paired, .connecting):
            return .orange
        case (.paired, .disconnected):
            return .red
        case (.paired, .error):
            return .red
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return String(localized: "connection_status_unpaired")
        case (.paired, .connected):
            return String(localized: "connection_status_connected")
        case (.paired, .connecting):
            return String(localized: "connection_status_connecting")
        case (.paired, .disconnected):
            return String(localized: "connection_status_disconnected")
        case (.paired, .error):
            return String(localized: "connection_status_error")
        default:
            return String(localized: "connection_status_unknown")
        }
    }

    private var reconnectStatusIcon: String {
        switch connectionState {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var reconnectStatusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .connecting:
            return .blue
        case .error:
            return .orange
        case .disconnected:
            return .secondary
        }
    }
}

struct RecognitionStatusView: View {
    let state: RecognitionState
    let statusMessage: String?
    let isEnabled: Bool
    let showsPairingAction: Bool
    let showsReconnectAction: Bool
    let audioLevel: CGFloat
    let onPressChanged: (Bool) -> Void
    let onReconnectAction: () -> Void

    @State private var isPressing = false
    @State private var hasStartedPressAction = false
    @State private var pendingPressWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(buttonBorderColor, lineWidth: isPressing ? 4 : 2)
                    )
                    .scaleEffect(isPressing ? 0.95 : 1)

                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(iconColor)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isInteractionEnabled else { return }
                        if !isPressing {
                            isPressing = true
                            startPendingPressAction()
                        }
                    }
                    .onEnded { _ in
                        guard isPressing else { return }
                        finishInteraction()
                    }
            )

            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if state == .listening {
                WaveformView(level: audioLevel)
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var isInteractionEnabled: Bool {
        RecognitionStatusInteractionPolicy.isInteractionEnabled(
            isEnabled: isEnabled,
            showsReconnectAction: showsReconnectAction
        )
    }

    private func startPendingPressAction() {
        let workItem = DispatchWorkItem {
            guard isPressing else { return }
            if showsReconnectAction {
                onReconnectAction()
                finishInteraction(resetOnly: true)
                return
            }
            guard isEnabled else { return }
            hasStartedPressAction = true
            onPressChanged(true)
        }

        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func finishInteraction(resetOnly: Bool = false) {
        pendingPressWorkItem?.cancel()
        pendingPressWorkItem = nil

        if resetOnly {
            isPressing = false
            hasStartedPressAction = false
            return
        }

        if hasStartedPressAction {
            onPressChanged(false)
        }

        isPressing = false
        hasStartedPressAction = false
    }

    private var iconName: String {
        if showsPairingAction {
            return "speaker.wave.2.fill"
        }
        if showsReconnectAction {
            return "antenna.radiowaves.left.and.right"
        }
        switch state {
        case .idle:
            return "mic.fill"
        case .listening:
            return "waveform"
        case .processing:
            return "waveform.circle"
        case .sending:
            return "arrow.up.circle.fill"
        }
    }

    private var iconColor: Color {
        if showsPairingAction {
            return isEnabled ? .orange : .gray
        }
        if showsReconnectAction {
            return .orange
        }
        switch state {
        case .idle:
            return isEnabled ? .blue : .gray
        case .listening:
            return .white
        case .processing:
            return .blue
        case .sending:
            return .green
        }
    }

    private var statusText: String {
        if showsPairingAction {
            return String(localized: "recognition_pair_now")
        }
        if showsReconnectAction {
            return String(localized: "recognition_mac_unavailable")
        }
        switch state {
        case .idle:
            return isEnabled ? String(localized: "recognition_hold_to_talk") : String(localized: "recognition_ready")
        case .listening:
            return String(localized: "recognition_listening")
        case .processing:
            return String(localized: "recognition_processing")
        case .sending:
            return String(localized: "recognition_sending")
        }
    }

    private var buttonBackgroundColor: Color {
        if showsPairingAction {
            return isEnabled ? Color.orange.opacity(0.18) : Color.gray.opacity(0.12)
        }
        if showsReconnectAction {
            return Color.orange.opacity(0.18)
        }
        switch state {
        case .idle:
            return isEnabled ? Color.blue.opacity(0.15) : Color.gray.opacity(0.12)
        case .listening:
            return .red
        case .processing:
            return Color.blue.opacity(0.15)
        case .sending:
            return Color.green.opacity(0.18)
        }
    }

    private var buttonBorderColor: Color {
        if showsPairingAction {
            return isEnabled ? .orange.opacity(0.6) : .gray.opacity(0.4)
        }
        if showsReconnectAction {
            return .orange.opacity(0.6)
        }
        switch state {
        case .idle:
            return isEnabled ? .blue.opacity(0.5) : .gray.opacity(0.4)
        case .listening:
            return .red.opacity(0.8)
        case .processing:
            return .blue.opacity(0.5)
        case .sending:
            return .green.opacity(0.6)
        }
    }
}

struct WaveformView: View {
    let level: CGFloat

    @State private var smoothedLevel: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let amplitude = max(0.12, min(smoothedLevel * 2.2, 1.4))
                let phase = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let centerY = size.height / 2
                    let width = size.width
                    let particleCount = 40
                    let spacing = width / CGFloat(particleCount - 1)
                    let baseRadius: CGFloat = 2.2

                    for index in 0..<particleCount {
                        let x = CGFloat(index) * spacing
                        let progress = x / width
                        let wave = sin((progress * 8 + phase) * .pi * 2)
                        let wave2 = sin((progress * 3 + phase * 0.7) * .pi * 2) * 0.35
                        let yOffset = (wave + wave2) * amplitude * (size.height * 0.28)
                        let y = centerY + yOffset

                        let intensity = min(1, max(0.2, amplitude))
                        let radius = baseRadius + intensity * 1.8
                        let alpha = 0.25 + intensity * 0.6
                        let hue = 0.55 + 0.08 * sin(phase + Double(progress) * 2)
                        let color = Color(hue: hue, saturation: 0.55, brightness: 0.95).opacity(alpha)

                        let rect = CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .onAppear {
            smoothedLevel = level
        }
        .onChange(of: level) { _, newValue in
            withAnimation(.linear(duration: 0.04)) {
                smoothedLevel = newValue
            }
        }
    }
}

struct TranscriptTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let autoScrollVersion: Int
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.text = text
        textView.isEditable = isEditable
        textView.isSelectable = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        uiView.isEditable = isEditable
        uiView.isSelectable = true

        if TranscriptTextViewSyncPolicy.shouldApplyExternalText(
            currentText: uiView.text,
            newText: text,
            isFirstResponder: uiView.isFirstResponder,
            hasMarkedText: uiView.markedTextRange != nil
        ) {
            uiView.text = text
        }

        if isEditable && isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder && uiView.markedTextRange == nil {
            uiView.resignFirstResponder()
        }

        if context.coordinator.lastAutoScrollVersion != autoScrollVersion {
            context.coordinator.lastAutoScrollVersion = autoScrollVersion
            autoScrollIfNeeded(uiView)
        }
    }

    private func autoScrollIfNeeded(_ uiView: UITextView) {
        uiView.layoutIfNeeded()

        let visibleHeight = uiView.bounds.height - uiView.textContainerInset.top - uiView.textContainerInset.bottom
        let contentHeight = uiView.contentSize.height - uiView.textContainerInset.top - uiView.textContainerInset.bottom

        guard TranscriptAutoScrollPolicy.shouldAutoScroll(
            contentHeight: contentHeight,
            visibleHeight: visibleHeight
        ) else {
            return
        }

        let bottomOffset = max(
            -uiView.adjustedContentInset.top,
            uiView.contentSize.height - uiView.bounds.height + uiView.adjustedContentInset.bottom
        )

        DispatchQueue.main.async {
            uiView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: true)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TranscriptTextView
        var lastAutoScrollVersion: Int

        init(parent: TranscriptTextView) {
            self.parent = parent
            self.lastAutoScrollVersion = parent.autoScrollVersion
        }

        func textViewDidChange(_ textView: UITextView) {
            guard parent.isEditable else { return }
            parent.text = textView.text ?? ""
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard parent.isEditable else { return }
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard parent.isEditable else { return }
            parent.isFocused = false
        }
    }
}
