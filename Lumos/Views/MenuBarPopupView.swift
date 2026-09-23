//
//  MenuBarPopupView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct MenuBarPopupView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    @ObservedObject var monitor: IdleActivityMonitor
    
    @State private var showingSettings: Bool = false
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
        self.monitor = .shared
    }
    
    public init(
        engine: KeyboardBacklightEngine,
        settings: LumosSettings,
        monitor: IdleActivityMonitor
    ) {
        self.engine = engine
        self.settings = settings
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: engine.isOn
                                        ? [Color.orange.opacity(0.8), Color.yellow]
                                        : [Color.secondary.opacity(0.3), Color.secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .shadow(color: engine.isOn ? Color.orange.opacity(0.4) : .clear, radius: 4)
                        
                        Image(systemName: "keyboard")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(engine.isOn ? Color.black.opacity(0.8) : Color.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lumos")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(engine.isOn ? "Teclado Iluminado" : "Backlight Desligado")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Power Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        engine.togglePower()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(engine.isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            .frame(width: 30, height: 30)
                            .shadow(color: engine.isOn ? Color.accentColor.opacity(0.4) : .clear, radius: 5)
                        
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(engine.isOn ? Color.white : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(engine.isOn ? "Desligar Iluminação" : "Ligar Iluminação")
            }
            
            Divider()
                .padding(.horizontal, -4)
            
            // Brightness Slider
            BrightnessSliderView(engine: engine)
            
            // Quick Presets
            PresetsView(engine: engine)
            
            Divider()
                .padding(.horizontal, -4)
            
            // Inactivity & Breathing Controls
            ActivityControlView(engine: engine, settings: settings, monitor: monitor)
            
            Divider()
                .padding(.horizontal, -4)
            
            // Bottom Action Bar
            HStack {
                Button {
                    showingSettings = true
                } label: {
                    Label("Ajustes", systemImage: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Encerrar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 290)
        .sheet(isPresented: $showingSettings) {
            SettingsSheetView(settings: settings, engine: engine)
        }
        .background(TouchBarView(engine: engine, settings: settings))
    }
}
