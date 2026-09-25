//
//  BrightnessSliderView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct BrightnessSliderView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    @ObservedObject var power: PowerManagementController
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
        self.power = .shared
    }
    
    public init(engine: KeyboardBacklightEngine, settings: LumosSettings) {
        self.engine = engine
        self.settings = settings
        self.power = .shared
    }
    
    private var percentage: Int {
        Int(round(engine.brightness * 100))
    }
    
    public var body: some View {
        let maxAllowed = engine.maxAllowedBrightness
        let isCapped = maxAllowed < 0.99
        
        VStack(spacing: 8) {
            HStack {
                Label("brightness_label", systemImage: "light.max")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if isCapped {
                    Text(String(format: String(localized: "slider_battery_cap_hint"), Int(round(maxAllowed * 100))))
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(power.isLowPowerMode && settings.lowPowerModeDimEnabled ? Color.orange : Color.blue)
                }
                
                Text("\(percentage)%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(engine.isOn ? .primary : .tertiary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: percentage)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Slider(
                    value: Binding(
                        get: { min(engine.brightness, maxAllowed) },
                        set: { newValue in
                            let clamped = min(newValue, maxAllowed)
                            engine.setBrightness(clamped)
                        }
                    ),
                    in: 0.0...1.0
                )
                .tint(isCapped ? (power.isLowPowerMode ? .orange : .blue) : .orange)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isCapped ? .tertiary : .secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}


#if DEBUG
#Preview {
    BrightnessSliderView()
}
#endif
