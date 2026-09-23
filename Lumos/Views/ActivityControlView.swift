//
//  ActivityControlView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct ActivityControlView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    @ObservedObject var monitor: IdleActivityMonitor
    
    private let durations: [(label: String, seconds: Double)] = [
        ("15s", 15.0),
        ("30s", 30.0),
        ("1m", 60.0),
        ("2m", 120.0),
        ("5m", 300.0)
    ]
    
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
        VStack(spacing: 8) {
            // Auto-Dim on Idle Card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .foregroundStyle(settings.autoDimEnabled ? Color.accentColor : Color.secondary)
                        Text("Auto-apagar por Inatividade")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if settings.autoDimEnabled {
                        Text(engine.isIdleDimmed ? "Teclado apagado por inatividade" : "Apaga se inativo por \(formatSeconds(settings.autoDimSeconds))")
                            .font(.caption2)
                            .foregroundStyle(engine.isIdleDimmed ? Color.orange : Color.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $settings.autoDimEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            
            // Timeout Picker if enabled
            if settings.autoDimEnabled {
                HStack(spacing: 6) {
                    ForEach(durations, id: \.seconds) { item in
                        let isSelected = settings.autoDimSeconds == item.seconds
                        Button {
                            withAnimation(.snappy) {
                                settings.autoDimSeconds = item.seconds
                            }
                        } label: {
                            Text(item.label)
                                .font(.caption.weight(isSelected ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func formatSeconds(_ sec: Double) -> String {
        if sec < 60 {
            return "\(Int(sec))s"
        } else {
            return "\(Int(sec / 60)) min"
        }
    }
}
