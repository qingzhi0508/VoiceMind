//
//  VoiceRelayiOSApp.swift
//  VoiceRelayiOS
//
//  Created by 谢庆智 on 2026/3/16.
//

import SwiftUI
import CoreData

@main
struct VoiceRelayiOSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
