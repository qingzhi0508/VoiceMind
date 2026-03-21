//
//  VoiceMindiOSApp.swift
//  VoiceMindiOS
//
//  Created by 谢庆智 on 2026/3/16.
//

import SwiftUI

@main
struct VoiceMindiOSApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @AppStorage("app_theme") private var appTheme: String = "system"

    var body: some Scene {
        WindowGroup {
            ContentView(hasLaunchedBefore: $hasLaunchedBefore)
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}
