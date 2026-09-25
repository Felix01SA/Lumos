//
//  LumosIntents.swift
//  Lumos
//
//  Created by Felix Almeida on 25/09/26.
//

import Foundation
import AppIntents

// MARK: - Set Keyboard Brightness Intent

@available(macOS 14.0, *)
public struct SetKeyboardBrightnessIntent: AppIntent {
    public static var title: LocalizedStringResource = "Set Keyboard Backlight"
    public static var description = IntentDescription("Sets the MacBook keyboard backlight brightness.")
    
    @Parameter(title: "Brightness (%)", default: 50, inclusiveRange: (0, 100))
    public var percentage: Int
    
    public init() {
        self.percentage = 50
    }
    
    public init(percentage: Int) {
        self.percentage = percentage
    }
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let level = Double(percentage) / 100.0
        KeyboardBacklightEngine.shared.setBrightness(level)
        let actual = Int(round(KeyboardBacklightEngine.shared.brightness * 100))
        return .result(value: actual)
    }
}

// MARK: - Toggle Keyboard Backlight Intent

@available(macOS 14.0, *)
public struct ToggleKeyboardBacklightIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Keyboard Backlight"
    public static var description = IntentDescription("Turns the MacBook keyboard backlight on or off.")
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        KeyboardBacklightEngine.shared.togglePower()
        return .result(value: KeyboardBacklightEngine.shared.isOn)
    }
}

// MARK: - Get Keyboard Brightness Intent

@available(macOS 14.0, *)
public struct GetKeyboardBrightnessIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Keyboard Backlight"
    public static var description = IntentDescription("Gets the current MacBook keyboard backlight brightness percentage.")
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let actual = Int(round(KeyboardBacklightEngine.shared.brightness * 100))
        return .result(value: actual)
    }
}

// MARK: - App Shortcuts Provider (Shortcuts & Siri integration)

@available(macOS 14.0, *)
public struct LumosShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleKeyboardBacklightIntent(),
            phrases: [
                "Toggle keyboard backlight in \(.applicationName)",
                "Alternar iluminação do teclado no \(.applicationName)",
                "Turn on keyboard backlight in \(.applicationName)",
                "Turn off keyboard backlight in \(.applicationName)"
            ],
            shortTitle: "Toggle Backlight",
            systemImageName: "keyboard"
        )
        
        AppShortcut(
            intent: SetKeyboardBrightnessIntent(),
            phrases: [
                "Set keyboard brightness in \(.applicationName)",
                "Definir brilho do teclado no \(.applicationName)"
            ],
            shortTitle: "Set Backlight",
            systemImageName: "light.max"
        )
    }
}
