//
//  MenuBarIconView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct MenuBarIconView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
    }
    
    public init(engine: KeyboardBacklightEngine, settings: LumosSettings) {
        self.engine = engine
        self.settings = settings
    }
    
    private var iconName: String {
        if !engine.isOn || engine.brightness < 0.02 {
            return "keyboard"
        } else if engine.brightness < 0.5 {
            return "keyboard.badge.ellipsis"
        } else {
            return "keyboard.fill"
        }
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
            
            if settings.showPercentageInMenuBar {
                Text("\(Int(round(engine.brightness * 100)))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
    }
}

#if DEBUG
#Preview {
    MenuBarIconView()
}
#endif
