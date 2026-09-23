//
//  BrightnessSliderView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct BrightnessSliderView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    
    @MainActor
    public init() {
        self.engine = .shared
    }
    
    public init(engine: KeyboardBacklightEngine) {
        self.engine = engine
    }
    
    private var percentage: Int {
        Int(round(engine.brightness * 100))
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Iluminação", systemImage: "light.max")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
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
                        get: { engine.brightness },
                        set: { newValue in
                            engine.setBrightness(newValue)
                        }
                    ),
                    in: 0.0...1.0
                )
                .tint(.orange)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}
