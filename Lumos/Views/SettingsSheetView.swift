//
//  SettingsSheetView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: LumosSettings
    @ObservedObject var engine: KeyboardBacklightEngine
    
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
        VStack(spacing: 18) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.8), Color.yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.orange.opacity(0.3), radius: 4)
                    
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumos")
                        .font(.title3.weight(.bold))
                    Text("Configurações do Teclado & Touch Bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Section: Interface & Menus
            VStack(alignment: .leading, spacing: 10) {
                Label("Barra de Menus & Sistema", systemImage: "menubar.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Toggle("Exibir porcentagem ao lado do ícone na Barra de Menus", isOn: $settings.showPercentageInMenuBar)
                    .toggleStyle(.checkbox)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Section: Touch Bar
            VStack(alignment: .leading, spacing: 10) {
                Label("Touch Bar do MacBook Pro", systemImage: "rectangle.topthird.inset.filled")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Toggle("Exibir atalho permanente no Control Strip", isOn: $settings.showInTouchBarControlStrip)
                    .toggleStyle(.checkbox)
                
                Text("Permite tocar no ícone de teclado no canto direito da Touch Bar sobre qualquer aplicativo para controlar a iluminação.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Section: Hardware
            VStack(alignment: .leading, spacing: 10) {
                Label("Hardware Detectado", systemImage: "laptopcomputer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Dispositivo:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(engine.hardwareModel)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Protocolo:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("IOKit HID (Report ID 1, 9 bytes)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Status:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(engine.isHardwareAvailable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(engine.isHardwareAvailable ? "Conectado e Ativo" : "Não encontrado")
                        }
                        .fontWeight(.medium)
                    }
                    .font(.caption)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Footer
            HStack {
                Text("Lumos v1.0 • macOS")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 420, height: 430)
    }
}

public typealias SettingsSheetView = SettingsView
