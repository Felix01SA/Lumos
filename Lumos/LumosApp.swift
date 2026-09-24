//
//  LumosApp.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

@main
struct LumosApp: App {
    @StateObject private var engine = KeyboardBacklightEngine.shared
    @StateObject private var settings = LumosSettings.shared
    @StateObject private var monitor = IdleActivityMonitor.shared
    @StateObject private var touchBarController = TouchBarController.shared
    @StateObject private var shortcutManager = KeyboardShortcutManager.shared

    var body: some Scene {
        let currentLocale = settings.appLanguage.effectiveLocale

        WindowGroup("window_title_main") {
            ContentView(engine: engine, settings: settings, monitor: monitor)
                .frame(width: 320)
                .fixedSize()
                .environment(\.locale, currentLocale)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(settings: settings, engine: engine)
                .environment(\.locale, currentLocale)
        }

        MenuBarExtra {
            MenuBarPopupView(engine: engine, settings: settings, monitor: monitor)
                .environment(\.locale, currentLocale)
        } label: {
            MenuBarIconView(engine: engine, settings: settings)
                .environment(\.locale, currentLocale)
        }
        .menuBarExtraStyle(.window)
    }
}
