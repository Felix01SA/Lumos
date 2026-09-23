//
//  KeyboardShortcutManager.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

// MARK: - Native Keyboard Shortcut Manager

@MainActor
public final class KeyboardShortcutManager: ObservableObject {
    public static let shared = KeyboardShortcutManager()
    
    @Published public private(set) var isAccessibilityTrusted: Bool = false
    @Published public private(set) var isTapActive: Bool = false
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accessibilityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let engine: KeyboardBacklightEngine
    private let settings: LumosSettings
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
        self.isAccessibilityTrusted = AXIsProcessTrusted()
        
        setupEventTap()
        startAccessibilityPollingIfNeeded()
        observeSettings()
    }
    
    @MainActor
    public init(engine: KeyboardBacklightEngine, settings: LumosSettings) {
        self.engine = engine
        self.settings = settings
        self.isAccessibilityTrusted = AXIsProcessTrusted()
        
        setupEventTap()
        startAccessibilityPollingIfNeeded()
        observeSettings()
    }
    
    deinit {
        accessibilityTimer?.invalidate()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
    
    // MARK: - Event Tap Setup
    
    public func setupEventTap() {
        guard settings.captureNativeShortcuts else {
            stopEventTap()
            return
        }
        
        isAccessibilityTrusted = AXIsProcessTrusted()
        guard isAccessibilityTrusted else {
            print("[Lumos] Accessibility permission not granted yet. Shortcuts will activate once allowed.")
            startAccessibilityPollingIfNeeded()
            return
        }
        
        if eventTap != nil {
            return
        }
        
        // Listen to keyDown and NX_SYSDEFINED (media keys)
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << 14)
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else {
                return Unmanaged.passRetained(event)
            }
            let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(refcon).takeUnretainedValue()
            
            // Auto re-enable tap if macOS disables it due to timeout
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }
            
            if manager.handleEvent(proxy: proxy, type: type, event: event) {
                // Return nil to swallow/consume the event
                return nil
            }
            
            return Unmanaged.passRetained(event)
        }
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("[Lumos] Warning: Failed to create CGEventTap.")
            isTapActive = false
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.isTapActive = true
        print("[Lumos] Native keyboard shortcut event tap active.")
    }
    
    public func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        isTapActive = false
    }
    
    // MARK: - Event Handling
    
    nonisolated private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Bool {
        Task { @MainActor in
            self.processEventOnMain(type: type, event: event)
        }
        
        // Fast synchronous check to determine whether to consume media keys immediately
        return shouldConsumeEvent(type: type, event: event)
    }
    
    nonisolated private func shouldConsumeEvent(type: CGEventType, event: CGEvent) -> Bool {
        if type.rawValue == 14 { // NX_SYSDEFINED
            guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
                return false
            }
            let data1 = nsEvent.data1
            let keyCode = Int((data1 & 0xFFFF0000) >> 16)
            let keyFlags = data1 & 0x0000FFFF
            let keyState = ((keyFlags & 0xFF00) >> 8) == 0x0A
            if keyState && (keyCode == 21 || keyCode == 22 || keyCode == 23) {
                return true
            }
        } else if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            if keycode == 96 || keycode == 97 {
                return true
            }
            let flags = event.flags
            if flags.contains(.maskControl) && flags.contains(.maskAlternate) {
                if keycode == 125 || keycode == 126 { // Down or Up arrow
                    return true
                }
            }
        }
        return false
    }
    
    @MainActor
    private func processEventOnMain(type: CGEventType, event: CGEvent) {
        guard settings.captureNativeShortcuts else { return }
        guard !engine.isSystemSleeping && !engine.isScreenSleeping && !engine.isLidClosed else { return }
        
        let flags = event.flags
        let isFineStep = flags.contains(.maskAlternate) && flags.contains(.maskShift)
        
        if type.rawValue == 14 {
            guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else { return }
            let data1 = nsEvent.data1
            let keyCode = Int((data1 & 0xFFFF0000) >> 16)
            let keyFlags = data1 & 0x0000FFFF
            let keyState = ((keyFlags & 0xFF00) >> 8) == 0x0A
            
            guard keyState else { return }
            
            switch keyCode {
            case 21: // NX_KEYTYPE_ILLUMINATION_UP
                engine.stepBrightnessUp(fine: isFineStep)
            case 22: // NX_KEYTYPE_ILLUMINATION_DOWN
                engine.stepBrightnessDown(fine: isFineStep)
            case 23: // NX_KEYTYPE_ILLUMINATION_TOGGLE
                engine.togglePower()
            default:
                break
            }
        } else if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            
            switch keycode {
            case 96: // kVK_F5
                engine.stepBrightnessDown(fine: isFineStep)
            case 97: // kVK_F6
                engine.stepBrightnessUp(fine: isFineStep)
            case 125: // Down Arrow with Ctrl+Opt
                if flags.contains(.maskControl) && flags.contains(.maskAlternate) {
                    engine.stepBrightnessDown(fine: isFineStep)
                }
            case 126: // Up Arrow with Ctrl+Opt
                if flags.contains(.maskControl) && flags.contains(.maskAlternate) {
                    engine.stepBrightnessUp(fine: isFineStep)
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Accessibility Permission Helpers
    
    private func startAccessibilityPollingIfNeeded() {
        accessibilityTimer?.invalidate()
        guard !isAccessibilityTrusted else { return }
        
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { timer.invalidate(); return }
                let trusted = AXIsProcessTrusted()
                if trusted != self.isAccessibilityTrusted {
                    self.isAccessibilityTrusted = trusted
                    if trusted {
                        timer.invalidate()
                        self.accessibilityTimer = nil
                        self.setupEventTap()
                    }
                }
            }
        }
    }
    
    public func promptForAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        startAccessibilityPollingIfNeeded()
    }
    
    public func openSystemSettingsAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func observeSettings() {
        settings.$captureNativeShortcuts
            .sink { [weak self] enabled in
                Task { @MainActor [weak self] in
                    if enabled {
                        self?.setupEventTap()
                    } else {
                        self?.stopEventTap()
                    }
                }
            }
            .store(in: &cancellables)
    }
}
