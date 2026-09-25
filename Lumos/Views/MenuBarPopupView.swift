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
    @ObservedObject var power: PowerManagementController
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
        self.monitor = .shared
        self.power = .shared
    }
    
    public init(
        engine: KeyboardBacklightEngine,
        settings: LumosSettings,
        monitor: IdleActivityMonitor
    ) {
        self.engine = engine
        self.settings = settings
        self.monitor = monitor
        self.power = .shared
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
                            .shadow(color: engine.isOn ? Color.orange.opacity(0.2 + engine.brightness * 0.4) : .clear, radius: 4 + CGFloat(engine.brightness * 5))
                        
                        Image("icon").resizable()
                            .frame(width: 40, height: 40)
//                            .font(.system(size: 13, weight: .bold))
//                            .foregroundStyle(engine.isOn ? Color.black.opacity(0.8) : Color.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("app_name")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text(engine.isOn ? "status_backlight_on" : "status_backlight_off")
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
                            .shadow(color: engine.isOn ? Color.accentColor.opacity(0.2 + engine.brightness * 0.35) : .clear, radius: 4 + CGFloat(engine.brightness * 4))
                        
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(engine.isOn ? Color.white : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey(engine.isOn ? "action_turn_off" : "action_turn_on"))
            }
            
            // Low Power Mode or Battery Optimization Badge
            if power.isLowPowerMode && settings.lowPowerModeDimEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("power_low_power_active")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("15% Máx")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.orange.opacity(0.2))
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )
                .foregroundStyle(Color.orange)
                .transition(.opacity.combined(with: .scale))
            } else if power.isOnBattery && settings.batteryOptimizationEnabled && engine.maxAllowedBrightness < 0.99 {
                HStack(spacing: 6) {
                    Image(systemName: "battery.75")
                        .font(.system(size: 11, weight: .bold))
                    Text("settings_battery_optimize")
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(round(engine.maxAllowedBrightness * 100)))% Máx")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.blue.opacity(0.2))
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                )
                .foregroundStyle(Color.blue)
                .transition(.opacity.combined(with: .scale))
            }
            
            Divider()
                .padding(.horizontal, -4)
            
            // Brightness Slider
            BrightnessSliderView(engine: engine, settings: settings)
            
            // Quick Presets
            PresetsView(engine: engine, settings: settings)
            
            Divider()
                .padding(.horizontal, -4)
            
            // Bottom Action Bar
            HStack {
                Button {
                    SettingsWindowController.shared.showWindow()
                } label: {
                    Label("action_settings", systemImage: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("action_quit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 290)
        .background(TouchBarView(engine: engine, settings: settings))
    }
}


#if DEBUG
#Preview {
    MenuBarPopupView()
}
#endif
