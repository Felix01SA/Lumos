//
//  LumosSettings.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case ptBR = "pt-BR"
    case en = "en"
    
    public var id: String { rawValue }
    
    public var displayName: LocalizedStringKey {
        switch self {
        case .system: return "language_system"
        case .ptBR: return "language_pt_br"
        case .en: return "language_en"
        }
    }
    
    public var effectiveLocale: Locale {
        switch self {
        case .system:
            return Locale.autoupdatingCurrent
        case .ptBR:
            return Locale(identifier: "pt-BR")
        case .en:
            return Locale(identifier: "en")
        }
    }
}

public final class LumosSettings: ObservableObject {
    public static let shared = LumosSettings()
    
    private enum Keys {
        static let appLanguage = "lumos.v2.appLanguage"
        static let autoDimEnabled = "lumos.v2.autoDimEnabled"
        static let autoDimSeconds = "lumos.v2.autoDimSeconds"
        static let dimLevel = "lumos.v2.dimLevel"
        static let showPercentageInMenuBar = "lumos.v2.showPercentageInMenuBar"
        static let lastActiveBrightness = "lumos.v2.lastActiveBrightness"
        static let showInTouchBarControlStrip = "lumos.v2.showInTouchBarControlStrip"
        static let syncBacklightWithTouchBar = "lumos.v2.syncBacklightWithTouchBar"
        static let touchBarDimLevel = "lumos.v2.touchBarDimLevel"
        static let touchBarDimSeconds = "lumos.v2.touchBarDimSeconds"
        static let touchBarSleepSeconds = "lumos.v2.touchBarSleepSeconds"
        static let sleepWithDisplayAndClamshell = "lumos.v2.sleepWithDisplayAndClamshell"
        static let captureNativeShortcuts = "lumos.v2.captureNativeShortcuts"
        static let showNativeOSDBezel = "lumos.v2.showNativeOSDBezel"
        static let batteryOptimizationEnabled = "lumos.v2.batteryOptimizationEnabled"
        static let batteryMaxBrightness = "lumos.v2.batteryMaxBrightness"
        static let lowPowerModeDimEnabled = "lumos.v2.lowPowerModeDimEnabled"
        static let disableOnExternalKeyboard = "lumos.v2.disableOnExternalKeyboard"
    }
    
    @Published public var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }
    
    @Published public var captureNativeShortcuts: Bool {
        didSet { UserDefaults.standard.set(captureNativeShortcuts, forKey: Keys.captureNativeShortcuts) }
    }
    
    @Published public var showNativeOSDBezel: Bool {
        didSet { UserDefaults.standard.set(showNativeOSDBezel, forKey: Keys.showNativeOSDBezel) }
    }
    
    @Published public var autoDimEnabled: Bool {
        didSet { UserDefaults.standard.set(autoDimEnabled, forKey: Keys.autoDimEnabled) }
    }
    
    @Published public var autoDimSeconds: Double {
        didSet { UserDefaults.standard.set(autoDimSeconds, forKey: Keys.autoDimSeconds) }
    }
    
    @Published public var dimLevel: Double {
        didSet { UserDefaults.standard.set(dimLevel, forKey: Keys.dimLevel) }
    }
    
    @Published public var showPercentageInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showPercentageInMenuBar, forKey: Keys.showPercentageInMenuBar) }
    }
    
    @Published public var lastActiveBrightness: Double {
        didSet { UserDefaults.standard.set(lastActiveBrightness, forKey: Keys.lastActiveBrightness) }
    }
    
    @Published public var showInTouchBarControlStrip: Bool {
        didSet { UserDefaults.standard.set(showInTouchBarControlStrip, forKey: Keys.showInTouchBarControlStrip) }
    }
    
    @Published public var syncBacklightWithTouchBar: Bool {
        didSet { UserDefaults.standard.set(syncBacklightWithTouchBar, forKey: Keys.syncBacklightWithTouchBar) }
    }
    
    @Published public var touchBarDimLevel: Double {
        didSet { UserDefaults.standard.set(touchBarDimLevel, forKey: Keys.touchBarDimLevel) }
    }
    
    @Published public var touchBarDimSeconds: Double {
        didSet { UserDefaults.standard.set(touchBarDimSeconds, forKey: Keys.touchBarDimSeconds) }
    }
    
    @Published public var touchBarSleepSeconds: Double {
        didSet { UserDefaults.standard.set(touchBarSleepSeconds, forKey: Keys.touchBarSleepSeconds) }
    }
    
    @Published public var sleepWithDisplayAndClamshell: Bool {
        didSet { UserDefaults.standard.set(sleepWithDisplayAndClamshell, forKey: Keys.sleepWithDisplayAndClamshell) }
    }
    
    @Published public var batteryOptimizationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(batteryOptimizationEnabled, forKey: Keys.batteryOptimizationEnabled)
            Task { @MainActor in
                KeyboardBacklightEngine.shared.enforceMaxBrightnessLimit()
            }
        }
    }
    
    @Published public var batteryMaxBrightness: Double {
        didSet {
            UserDefaults.standard.set(batteryMaxBrightness, forKey: Keys.batteryMaxBrightness)
            Task { @MainActor in
                KeyboardBacklightEngine.shared.enforceMaxBrightnessLimit()
            }
        }
    }
    
    @Published public var lowPowerModeDimEnabled: Bool {
        didSet {
            UserDefaults.standard.set(lowPowerModeDimEnabled, forKey: Keys.lowPowerModeDimEnabled)
            Task { @MainActor in
                KeyboardBacklightEngine.shared.enforceMaxBrightnessLimit()
            }
        }
    }
    
    @Published public var disableOnExternalKeyboard: Bool {
        didSet {
            UserDefaults.standard.set(disableOnExternalKeyboard, forKey: Keys.disableOnExternalKeyboard)
            Task { @MainActor in
                KeyboardBacklightEngine.shared.evaluateBacklightPowerState()
            }
        }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        if let rawLang = defaults.string(forKey: Keys.appLanguage),
           let lang = AppLanguage(rawValue: rawLang) {
            self.appLanguage = lang
        } else {
            self.appLanguage = .system
        }
        self.autoDimEnabled = defaults.object(forKey: Keys.autoDimEnabled) as? Bool ?? false
        self.autoDimSeconds = defaults.object(forKey: Keys.autoDimSeconds) as? Double ?? 120.0
        self.dimLevel = defaults.object(forKey: Keys.dimLevel) as? Double ?? 0.0
        self.showPercentageInMenuBar = defaults.object(forKey: Keys.showPercentageInMenuBar) as? Bool ?? false
        self.lastActiveBrightness = defaults.object(forKey: Keys.lastActiveBrightness) as? Double ?? 0.75
        self.showInTouchBarControlStrip = defaults.object(forKey: Keys.showInTouchBarControlStrip) as? Bool ?? true
        
        let defaultSync = TouchBarController.isTouchBarAvailable
        self.syncBacklightWithTouchBar = defaults.object(forKey: Keys.syncBacklightWithTouchBar) as? Bool ?? defaultSync
        self.touchBarDimLevel = defaults.object(forKey: Keys.touchBarDimLevel) as? Double ?? 0.15
        self.touchBarDimSeconds = defaults.object(forKey: Keys.touchBarDimSeconds) as? Double ?? 60.0
        self.touchBarSleepSeconds = defaults.object(forKey: Keys.touchBarSleepSeconds) as? Double ?? 75.0
        self.sleepWithDisplayAndClamshell = defaults.object(forKey: Keys.sleepWithDisplayAndClamshell) as? Bool ?? true
        self.captureNativeShortcuts = defaults.object(forKey: Keys.captureNativeShortcuts) as? Bool ?? true
        self.showNativeOSDBezel = defaults.object(forKey: Keys.showNativeOSDBezel) as? Bool ?? true
        self.batteryOptimizationEnabled = defaults.object(forKey: Keys.batteryOptimizationEnabled) as? Bool ?? true
        self.batteryMaxBrightness = defaults.object(forKey: Keys.batteryMaxBrightness) as? Double ?? 0.50
        self.lowPowerModeDimEnabled = defaults.object(forKey: Keys.lowPowerModeDimEnabled) as? Bool ?? true
        self.disableOnExternalKeyboard = defaults.object(forKey: Keys.disableOnExternalKeyboard) as? Bool ?? false
    }
}
