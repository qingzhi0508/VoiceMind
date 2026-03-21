import SwiftUI
import Combine

// MARK: - Time-Based Color Scheme

enum TimeOfDay {
    case morning    // 6-10
    case afternoon  // 10-17
    case evening    // 17-21
    case night      // 21-6

    var greeting: String {
        switch self {
        case .morning: return "早上好"
        case .afternoon: return "下午好"
        case .evening: return "傍晚好"
        case .night: return "夜深了"
        }
    }

    var greeting_en: String {
        switch self {
        case .morning: return "Good Morning"
        case .afternoon: return "Good Afternoon"
        case .evening: return "Good Evening"
        case .night: return "Good Night"
        }
    }
}

// MARK: - Time-Based Colors

struct TimeBasedColors {
    let primaryGradient: [Color]
    let secondaryColor: Color
    let accentColor: Color
    let backgroundGradient: [Color]
    let cardBackground: Color
    let textPrimary: Color
    let textSecondary: Color

    static func colors(for timeOfDay: TimeOfDay) -> TimeBasedColors {
        switch timeOfDay {
        case .morning:
            return TimeBasedColors(
                primaryGradient: [Color(hex: "FF6B6B"), Color(hex: "FFA500")],  // 橙红渐变
                secondaryColor: Color(hex: "FFB347"),
                accentColor: Color(hex: "FF6B6B"),
                backgroundGradient: [Color(hex: "FFF5E6"), Color(hex: "FFE4C4")],  // 暖白
                cardBackground: Color(hex: "FFFAF0").opacity(0.9),
                textPrimary: Color(hex: "4A3728"),
                textSecondary: Color(hex: "7D6354")
            )

        case .afternoon:
            return TimeBasedColors(
                primaryGradient: [Color(hex: "4A90E2"), Color(hex: "50C9C3")],  // 蓝绿渐变
                secondaryColor: Color(hex: "50C9C3"),
                accentColor: Color(hex: "4A90E2"),
                backgroundGradient: [Color(hex: "F0F8FF"), Color(hex: "E6F2FF")],  // 淡蓝
                cardBackground: Color(hex: "FFFFFF").opacity(0.85),
                textPrimary: Color(hex: "2C3E50"),
                textSecondary: Color(hex: "5D6D7E")
            )

        case .evening:
            return TimeBasedColors(
                primaryGradient: [Color(hex: "9B59B6"), Color(hex: "E74C8C")],  // 紫粉渐变
                secondaryColor: Color(hex: "E74C8C"),
                accentColor: Color(hex: "9B59B6"),
                backgroundGradient: [Color(hex: "F5EEF8"), Color(hex: "EBDEF0")],  // 淡紫
                cardBackground: Color(hex: "FDFEFE").opacity(0.9),
                textPrimary: Color(hex: "4A235A"),
                textSecondary: Color(hex: "7D6608")
            )

        case .night:
            return TimeBasedColors(
                primaryGradient: [Color(hex: "2C3E50"), Color(hex: "34495E")],  // 深蓝灰
                secondaryColor: Color(hex: "5D6D7E"),
                accentColor: Color(hex: "3498DB"),
                backgroundGradient: [Color(hex: "1A1A2E"), Color(hex: "16213E")],  // 深蓝黑
                cardBackground: Color(hex: "0F3460").opacity(0.7),
                textPrimary: Color(hex: "ECF0F1"),
                textSecondary: Color(hex: "BDC3C7")
            )
        }
    }
}

// MARK: - Color Manager

class TimeBasedColorManager: ObservableObject {
    static let shared = TimeBasedColorManager()

    @Published var currentColors: TimeBasedColors
    @Published var timeOfDay: TimeOfDay
    @Published var greeting: String

    private var timer: Timer?

    init() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let tod = Self.timeOfDay(for: hour)
        self.timeOfDay = tod
        self.currentColors = TimeBasedColors.colors(for: tod)
        self.greeting = tod.greeting

        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        // Update every minute to check for time of day change
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateColorsIfNeeded()
        }
    }

    private func updateColorsIfNeeded() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let newTimeOfDay = Self.timeOfDay(for: hour)

        if newTimeOfDay != self.timeOfDay {
            DispatchQueue.main.async {
                self.timeOfDay = newTimeOfDay
                self.currentColors = TimeBasedColors.colors(for: newTimeOfDay)
            }
        }
    }

    static func timeOfDay(for hour: Int) -> TimeOfDay {
        switch hour {
        case 6..<10: return .morning
        case 10..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
