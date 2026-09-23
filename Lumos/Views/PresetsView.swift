//
//  PresetsView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct PresetsView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    
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
    }
    
    public init(engine: KeyboardBacklightEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets Rápidos")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            
            HStack(spacing: 6) {
                ForEach(presets, id: \.value) { preset in
                    let isSelected = isPresetActive(preset.value)
                    
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
                                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 8, style: .continuous)
//                                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.8), lineWidth: 1)
//                            )
                    }
                    .buttonStyle(.plain).border(.clear)
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
