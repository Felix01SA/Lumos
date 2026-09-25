//
//  PresetsView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct PresetsView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    @ObservedObject var power: PowerManagementController
    
    private let presets: [(label: String, value: Double)] = [
        ("0%", 0.0),
        ("25%", 0.25),
        ("50%", 0.50),
        ("75%", 0.75),
        ("100%", 1.0)
    ]
    
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
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("presets_title")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            
            HStack(spacing: 6) {
                ForEach(presets, id: \.value) { preset in
                    let isCapped = preset.value > engine.maxAllowedBrightness
                    let isSelected = !isCapped && isPresetActive(preset.value)
                    
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            engine.applyPreset(preset.value)
                        }
                    } label: {
                        Text(preset.label)
                            .font(.system(.caption, design: .rounded).weight(isSelected ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor).opacity(isCapped ? 0.4 : 1.0))
                            )
                            .foregroundStyle(isSelected ? Color.white : (isCapped ? Color.secondary.opacity(0.4) : Color.primary))
                    }
                    .buttonStyle(.plain).border(.clear)
                    .disabled(isCapped)
//                    .opacity(isCapped ? 0.8 : 1.0)
                    .help(isCapped ? String(localized: "preset_disabled_by_power_saving") : "")
                }
            }
        }
    }
    
    private func isPresetActive(_ value: Double) -> Bool {
        if value == 0.0 {
            return !engine.isOn || engine.brightness < 0.02
        }
        return abs(engine.brightness - value) < 0.08
    }
}

#if DEBUG
#Preview {
    PresetsView()
}
#endif
