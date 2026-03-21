import Foundation

struct MenuBarStatusPresentation {
    let buttonTitle: String
    let menuStatusTitle: String
    let accessibilityDescription: String
    let iconName: String
    let showsUnpairAction: Bool

    init(pairingState: PairingState, connectionState: ConnectionState) {
        let appTitle = AppLocalization.localizedString("app_title")

        switch pairingState {
        case .unpaired:
            self.buttonTitle = appTitle
            self.menuStatusTitle = AppLocalization.localizedString("menu_status_unpaired")
            self.accessibilityDescription = String(localized: "status_access_unpaired")
            self.iconName = "mic.circle"
            self.showsUnpairAction = false
        case .pairing:
            self.buttonTitle = appTitle
            self.menuStatusTitle = AppLocalization.localizedString("status_menu_pairing")
            self.accessibilityDescription = String(localized: "status_access_pairing")
            self.iconName = "mic.circle.fill"
            self.showsUnpairAction = false
        case .paired(_, let deviceName):
            switch connectionState {
            case .connected:
                self.buttonTitle = String(localized: "status_connection_connected")
                self.menuStatusTitle = String(format: String(localized: "status_menu_connected_format"), deviceName)
                self.accessibilityDescription = String(localized: "status_connection_connected")
                self.iconName = "mic.circle.fill"
            case .connecting:
                self.buttonTitle = appTitle
                self.menuStatusTitle = String(localized: "status_connection_connecting")
                self.accessibilityDescription = String(localized: "status_connection_connecting")
                self.iconName = "mic.circle.badge.clock"
            case .disconnected:
                self.buttonTitle = appTitle
                self.menuStatusTitle = String(localized: "status_paired_not_connected")
                self.accessibilityDescription = String(localized: "status_connection_disconnected")
                self.iconName = "mic.circle"
            case .error:
                self.buttonTitle = appTitle
                self.menuStatusTitle = String(localized: "status_connection_error")
                self.accessibilityDescription = String(localized: "status_connection_error")
                self.iconName = "mic.circle"
            }
            self.showsUnpairAction = true
        }
    }
}
