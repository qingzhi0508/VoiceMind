import Foundation

enum TextInjectionMethod: String, Codable, CaseIterable {
    case clipboard = "clipboard"
    case cgEvent = "cgEvent"

    var displayName: String {
        switch self {
        case .clipboard:
            return "剪贴板粘贴"
        case .cgEvent:
            return "字符注入"
        }
    }

    var description: String {
        switch self {
        case .clipboard:
            return "将文本复制到剪贴板并模拟 Cmd+V 粘贴（推荐，兼容性最好）"
        case .cgEvent:
            return "逐字符发送键盘事件（不影响剪贴板，但某些应用可能不支持）"
        }
    }
}
