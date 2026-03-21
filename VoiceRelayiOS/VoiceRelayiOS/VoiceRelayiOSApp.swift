//
//  VoiceRelayiOSApp.swift
//  VoiceRelayiOS
//
//  Created by 谢庆智 on 2026/3/16.
//

import SwiftUI

@main
struct VoiceRelayiOSApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView(hasLaunchedBefore: $hasLaunchedBefore)
        }
    }
}
