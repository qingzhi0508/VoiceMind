import Foundation

protocol TextInjecting {
    func inject(_ text: String) throws
}

enum TextInjectionError: Error, Equatable {
    case accessibilityPermissionDenied
    case noFocusedInputTarget
    case injectionFailed(String)
}

enum TextInjectionDeliveryOutcome: Equatable {
    case injected
    case permissionRequired
    case fallbackToCopy(reason: String)
}

struct TextInjectionCoordinator {
    let injector: TextInjecting

    func deliver(text: String) -> TextInjectionDeliveryOutcome {
        do {
            try injector.inject(text)
            return .injected
        } catch let error as TextInjectionError {
            switch error {
            case .accessibilityPermissionDenied:
                return .permissionRequired
            case .noFocusedInputTarget:
                return .fallbackToCopy(reason: "No focused input target")
            case .injectionFailed(let reason):
                return .fallbackToCopy(reason: reason)
            }
        } catch {
            return .fallbackToCopy(reason: error.localizedDescription)
        }
    }
}
