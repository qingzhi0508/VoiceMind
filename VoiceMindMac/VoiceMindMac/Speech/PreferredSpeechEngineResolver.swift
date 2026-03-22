import Foundation

enum PreferredSpeechEngineResolver {
    static func resolve(
        savedEngineId: String,
        availableEngineIds: Set<String>,
        fallbackEngineId: String
    ) -> String {
        let trimmedSavedEngineId = savedEngineId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSavedEngineId.isEmpty else {
            return fallbackEngineId
        }

        guard availableEngineIds.contains(trimmedSavedEngineId) else {
            return fallbackEngineId
        }

        return trimmedSavedEngineId
    }
}
