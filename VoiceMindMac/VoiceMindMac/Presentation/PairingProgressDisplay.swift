import Foundation

enum PairingProgressDisplay {
    static func message(
        pairingState: PairingState,
        connectionState: ConnectionState,
        progressMessage: String?
    ) -> String? {
        switch (pairingState, connectionState) {
        case let (.paired(_, deviceName), .connected):
            return String(format: AppLocalization.localizedString("pairing_progress_connected_ready_format"), deviceName)
        case let (.paired(_, deviceName), .connecting):
            return String(format: AppLocalization.localizedString("pairing_progress_connecting_format"), deviceName)
        case let (.paired(_, deviceName), .disconnected):
            return String(format: AppLocalization.localizedString("pairing_progress_waiting_reconnect_format"), deviceName)
        case let (.paired(_, deviceName), .error):
            return String(format: AppLocalization.localizedString("pairing_progress_connection_error_format"), deviceName)
        default:
            return progressMessage
        }
    }
}
