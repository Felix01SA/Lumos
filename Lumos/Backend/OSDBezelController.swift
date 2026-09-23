//
//  OSDBezelController.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import AppKit
import Foundation

// MARK: - Native macOS OSD Bezel Controller

@MainActor
public final class OSDBezelController {
    public static let shared = OSDBezelController()
    
    private typealias ShowChicletsFunc = @convention(c) (
        AnyObject,
        Selector,
        Int64,   // image type (1 = Keyboard Backlight)
        UInt32,  // displayID
        UInt32,  // priority
        UInt32,  // msecUntilFade
        UInt32,  // filledChiclets
        UInt32,  // totalChiclets
        Bool     // locked
    ) -> Void
    
    private var showChiclets: ShowChicletsFunc?
    private var osdSharedManager: AnyObject?
    private var showSelector: Selector?
    public private(set) var isAvailable: Bool = false
    
    private init() {
        setup()
    }
    
    private func setup() {
        guard dlopen("/System/Library/PrivateFrameworks/OSD.framework/OSD", RTLD_NOW) != nil else {
            return
        }
        guard let osdClass = NSClassFromString("OSDManager") as? NSObject.Type else {
            return
        }
        let selShared = NSSelectorFromString("sharedManager")
        guard let shared = osdClass.perform(selShared)?.takeUnretainedValue() else {
            return
        }
        
        let sel = NSSelectorFromString("showImage:onDisplayID:priority:msecUntilFade:filledChiclets:totalChiclets:locked:")
        guard shared.responds(to: sel) else {
            return
        }
        
        let method = class_getMethodImplementation(object_getClass(shared), sel)
        self.showChiclets = unsafeBitCast(method, to: ShowChicletsFunc.self)
        self.osdSharedManager = shared
        self.showSelector = sel
        self.isAvailable = true
    }
    
    /// Displays the native macOS On-Screen Display (OSD) overlay for keyboard backlight
    /// - Parameters:
    ///   - brightness: Brightness level from 0.0 to 1.0
    ///   - locked: Whether the backlight adjustment is locked/blocked (e.g. ambient light too high)
    public func showBacklightBezel(brightness: Double, locked: Bool = false) {
        guard isAvailable,
              let shared = osdSharedManager,
              let sel = showSelector,
              let show = showChiclets else {
            return
        }
        
        let clamped = min(max(brightness, 0.0), 1.0)
        let totalChiclets: UInt32 = 16
        let filledChiclets = UInt32(round(clamped * Double(totalChiclets)))
        
        // Image 11: Apple Keyboard Backlight (kBright.pdf)
        // Image 12: Apple Keyboard Backlight Off (kBrightOff.pdf)
        let imageType: Int64 = (filledChiclets == 0) ? 12 : 11
        
        // Priority 1: High priority UI overlay
        // 1100ms fade duration
        show(shared, sel, imageType, CGMainDisplayID(), 1, 1100, filledChiclets, totalChiclets, locked)
    }
}
