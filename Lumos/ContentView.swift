//
//  ContentView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    @ObservedObject var monitor: IdleActivityMonitor

    @MainActor
    init() {
        self.engine = .shared
        self.settings = .shared
        self.monitor = .shared
    }

    init(
        engine: KeyboardBacklightEngine,
        settings: LumosSettings,
        monitor: IdleActivityMonitor
    ) {
        self.engine = engine
        self.settings = settings
        self.monitor = monitor
    }

    var body: some View {
        MenuBarPopupView(engine: engine, settings: settings, monitor: monitor)
            .padding(10)
            .background(TouchBarView(engine: engine, settings: settings))
    }
}
