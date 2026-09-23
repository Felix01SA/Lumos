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

    var body: some Scene {
        WindowGroup("Lumos — Controle de Backlight") {
            ContentView(engine: engine, settings: settings, monitor: monitor)
                .frame(width: 320)
                .fixedSize()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(settings: settings, engine: engine)
        }

        MenuBarExtra {
            MenuBarPopupView(engine: engine, settings: settings, monitor: monitor)
        } label: {
            MenuBarIconView(engine: engine, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
