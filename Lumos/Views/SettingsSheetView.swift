//
//  SettingsSheetView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI
import ServiceManagement

public struct SettingsSheetView: View {
    @ObservedObject var settings: LumosSettings
    @ObservedObject var engine: KeyboardBacklightEngine
    @Environment(\.dismiss) private var dismiss
    
    @MainActor
    public init() {
        self.settings = .shared
        self.engine = .shared
    }
    
    public init(settings: LumosSettings, engine: KeyboardBacklightEngine) {
        self.settings = settings
        self.engine = engine
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "keyboard.badge.waveform")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumos")
                        .font(.headline)
                    Text("Configurações & Hardware")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Options
            VStack(alignment: .leading, spacing: 12) {
                Text("Barra de Menus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Toggle("Exibir porcentagem ao lado do ícone", isOn: $settings.showPercentageInMenuBar)
                    .toggleStyle(.checkbox)
                
                Divider()
                
                Text("Touch Bar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Toggle("Atalho no Control Strip da Touch Bar", isOn: $settings.showInTouchBarControlStrip)
                    .toggleStyle(.checkbox)
                
                Divider()
                
                Text("Hardware Detectado")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Dispositivo:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(engine.hardwareModel)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Status:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(engine.isHardwareAvailable ? Color.green : Color.red)
                                .frame(width: 7, height: 7)
                            Text(engine.isHardwareAvailable ? "Conectado (IOKit HID)" : "Não encontrado")
                        }
                        .fontWeight(.medium)
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("Lumos v1.0 • macOS")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Fechar") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
    }
}
