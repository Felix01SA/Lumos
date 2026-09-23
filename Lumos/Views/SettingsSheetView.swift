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
    @ObservedObject var touchBar: TouchBarController
    
    @MainActor
    public init() {
        self.settings = .shared
        self.engine = .shared
        self.touchBar = .shared
    }
    
    @MainActor
    public init(settings: LumosSettings, engine: KeyboardBacklightEngine) {
        self.settings = settings
        self.engine = engine
        self.touchBar = .shared
    }
    
    @MainActor
    public init(settings: LumosSettings, engine: KeyboardBacklightEngine, touchBar: TouchBarController) {
        self.settings = settings
        self.engine = engine
        self.touchBar = touchBar
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
                HStack {
                    Label("Touch Bar do MacBook Pro", systemImage: "rectangle.topthird.inset.filled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if TouchBarController.isTouchBarAvailable {
                        let stage = touchBar.displayStage
                        let stageColor: Color = {
                            switch stage {
                            case .active: return .green
                            case .dimmed: return .yellow
                            case .sleeping: return .orange
                            }
                        }()
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(stageColor)
                                .frame(width: 7, height: 7)
                            Text(stage.rawValue)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(stageColor)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(stageColor.opacity(0.12))
                        )
                    } else {
                        Text("Não detectada")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if TouchBarController.isTouchBarAvailable {
                    Toggle("Exibir atalho permanente no Control Strip", isOn: $settings.showInTouchBarControlStrip)
                        .toggleStyle(.checkbox)
                    
                    Text("Permite tocar no ícone de teclado no canto direito da Touch Bar sobre qualquer aplicativo para controlar a iluminação.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Sincronizar iluminação com o ciclo da Touch Bar", isOn: $settings.syncBacklightWithTouchBar)
                        .toggleStyle(.checkbox)
                        .padding(.top, 4)
                    
                    Text("Diminui o teclado quando a Touch Bar esmaecer (~60s), apaga quando a Touch Bar desligar (~75s) e religa instantaneamente ao tocar no teclado, trackpad ou Touch Bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if settings.syncBacklightWithTouchBar {
                        HStack(spacing: 8) {
                            Text("Brilho ao diminuir (dimming):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.touchBarDimLevel, in: 0.05...0.40, step: 0.05)
                                .frame(width: 120)
                            Text("\(Int(round(settings.touchBarDimLevel * 100)))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.leading, 18)
                        .padding(.top, 2)
                    }
                } else {
                    Text("Este dispositivo não possui Touch Bar física integrada.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .frame(width: 440, height: 535)
    }
}

public typealias SettingsSheetView = SettingsView
