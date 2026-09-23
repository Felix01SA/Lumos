//
//  LumosSettings.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI
import Combine

public final class LumosSettings: ObservableObject {
    public static let shared = LumosSettings()
    
    private enum Keys {
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
    
    private init() {
        let defaults = UserDefaults.standard
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
    }
}
