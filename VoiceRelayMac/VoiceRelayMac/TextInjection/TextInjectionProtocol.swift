import Foundation

protocol TextInjectionProtocol {
    /// Inject text into the currently focused application
    func inject(_ text: String) throws

    /// Whether this injection method requires Accessibility permission
    var requiresAccessibilityPermission: Bool { get }
}

enum TextInjectionError: Error {
    case accessibilityPermissionDenied
    case injectionFailed(String)
}
