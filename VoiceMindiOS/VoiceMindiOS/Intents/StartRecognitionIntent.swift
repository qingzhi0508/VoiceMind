import AppIntents
import Foundation

struct StartLocalRecognitionIntent: AppIntent {
    static var title: LocalizedStringResource = "Local Recognition"
    static var description: IntentDescription = IntentDescription(
        "Start on-device voice recognition"
    )
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .voiceMindStartLocalRecognition,
            object: nil
        )
        return .result()
    }
}

struct StartRemoteRecognitionIntent: AppIntent {
    static var title: LocalizedStringResource = "Remote Recognition"
    static var description: IntentDescription = IntentDescription(
        "Start remote voice recognition via Mac"
    )
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .voiceMindStartRemoteRecognition,
            object: nil
        )
        return .result()
    }
}

extension Notification.Name {
    static let voiceMindStartLocalRecognition = Notification.Name(
        "VoiceMind.startLocalRecognition"
    )
    static let voiceMindStartRemoteRecognition = Notification.Name(
        "VoiceMind.startRemoteRecognition"
    )
}
