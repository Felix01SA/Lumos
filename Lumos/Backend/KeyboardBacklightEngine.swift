//
//  KeyboardBacklightEngine.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import AppKit
import Foundation
import Combine
import IOKit
import IOKit.hid
import IOKit.pwr_mgt

// MARK: - Keyboard Backlight Engine

@MainActor
public final class KeyboardBacklightEngine: ObservableObject {
    public static let shared = KeyboardBacklightEngine()
    
    // Direct WebHID-style IOHIDManager
    private var hidManager: IOHIDManager?
    private var directDevices: [IOHIDDevice] = []
    
    // Hardware ranges (exact WebHID protocol: 0 to 512)
    public let minOn: Int = 0
    public let maxOn: Int = 512
    public let offVal: Int = 0
    
    // Observable states
    @Published public private(set) var isHardwareAvailable: Bool = false
    @Published public private(set) var hardwareModel: String = "MacBook Keyboard Backlight"
    @Published public private(set) var isOn: Bool = false
    @Published public private(set) var isIdleDimmed: Bool = false
    @Published public private(set) var touchBarSyncStage: TouchBarController.TouchBarDisplayStage = .active
    
    // Power & Display state tracking (Repouso, Tela desligada, Tampa fechada)
    @Published public private(set) var isScreenSleeping: Bool = false
    @Published public private(set) var isSystemSleeping: Bool = false
    @Published public private(set) var isLidClosed: Bool = false
    @Published public private(set) var isPowerSavingDimmed: Bool = false
    
    private var notifyPort: IONotificationPortRef?
    private var rootDomainNotifier: io_object_t = 0
    
    public var isTouchBarSleeping: Bool {
        touchBarSyncStage == .sleeping
    }
    
    public var isTouchBarDimmed: Bool {
        touchBarSyncStage == .dimmed
    }
    
    @Published public var brightness: Double = 0.75 {
        didSet {
            let maxVal = maxAllowedBrightness
            let clamped = min(max(brightness, 0.0), maxVal)
            if clamped != brightness {
                brightness = clamped
                return
            }
            if !isApplyingInternalState {
                applyBrightnessToHardware(clamped)
                if clamped > 0.01 {
                    LumosSettings.shared.lastActiveBrightness = clamped
                }
            }
            isOn = clamped > 0.01
        }
    }
    
    public var rawBrightness: Int {
        normalizedToRaw(brightness)
    }
    
    private var isApplyingInternalState: Bool = false
    private var preDimBrightness: Double = 0.75
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupDirectHID()
        setupSleepWakeListeners()
        
        // Restore last known brightness or start at 75%
        let initial = LumosSettings.shared.lastActiveBrightness
        self.brightness = initial > 0.01 ? initial : 0.75
        self.isOn = self.brightness > 0.01
        applyBrightnessToHardware(self.brightness)
    }
    
    deinit {
        if let port = notifyPort {
            IONotificationPortDestroy(port)
        }
        if rootDomainNotifier != 0 {
            IOObjectRelease(rootDomainNotifier)
        }
    }
    
    // MARK: - Direct WebHID Setup
    
    private func setupDirectHID() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = manager
        
        // Exact WebHID filter: Apple (0x05ac), usagePage: 0xff00, usage: 0x0f
        let match: [String: Any] = [
            kIOHIDVendorIDKey: 0x05ac,
            kIOHIDPrimaryUsagePageKey: 0xff00,
            kIOHIDPrimaryUsageKey: 0x0f
        ]
        
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        refreshDirectDevices()
    }
    
    public func refreshDirectDevices() {
        guard let manager = hidManager else { return }
        directDevices.removeAll()
        
        if let devSet = IOHIDManagerCopyDevices(manager) {
            let count = CFSetGetCount(devSet)
            var devArray = [UnsafeRawPointer?](repeating: nil, count: count)
            CFSetGetValues(devSet, &devArray)
            
            for ptr in devArray {
                guard let ptr = ptr else { continue }
                let dev = unsafeBitCast(ptr, to: IOHIDDevice.self)
                _ = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
                directDevices.append(dev)
                if let prod = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String {
                    self.hardwareModel = prod
                }
            }
        }
        
        self.isHardwareAvailable = !directDevices.isEmpty
        print("[Lumos] Connected to \(directDevices.count) direct Keyboard Backlight device(s). Hardware available: \(isHardwareAvailable)")
    }
    
    // MARK: - Sleep, Display & Clamshell Listeners (Repouso, Tela desligada, Tampa fechada)
    
    private func setupSleepWakeListeners() {
        let center = NSWorkspace.shared.notificationCenter
        
        // 1. System Sleep (quando o MacBook entrar em repouso)
        center.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("[Lumos] System entering sleep. Turning off keyboard backlight...")
                    self.isSystemSleeping = true
                    self.evaluateBacklightPowerState()
                }
            }
            .store(in: &cancellables)
        
        center.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("[Lumos] System woke up from sleep. Evaluating backlight...")
                    self.isSystemSleeping = false
                    self.refreshDirectDevices()
                    self.evaluateBacklightPowerState()
                }
            }
            .store(in: &cancellables)
        
        // 2. Display Sleep (quando a tela apagar)
        center.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("[Lumos] Display turned off. Turning off keyboard backlight...")
                    self.isScreenSleeping = true
                    self.evaluateBacklightPowerState()
                }
            }
            .store(in: &cancellables)
        
        center.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("[Lumos] Display turned on. Evaluating backlight...")
                    self.isScreenSleeping = false
                    self.evaluateBacklightPowerState()
                }
            }
            .store(in: &cancellables)
            
        // 3. Clamshell / Lid Listener (quando a tela baixar)
        setupClamshellListener()
    }
    
    private func setupClamshellListener() {
        let matching = IOServiceMatching("IOPMrootDomain")
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard rootDomain != 0 else { return }
        
        // Initial state
        self.isLidClosed = checkIsLidClosed()
        
        let port = IONotificationPortCreate(kIOMainPortDefault)
        self.notifyPort = port
        
        if let runLoopSrc = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSrc, .defaultMode)
        }
        
        let callback: IOServiceInterestCallback = { (refcon, service, messageType, messageArgument) in
            guard let refcon = refcon else { return }
            let engine = Unmanaged<KeyboardBacklightEngine>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                engine.handleClamshellMessage()
            }
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let kr = IOServiceAddInterestNotification(
            port,
            rootDomain,
            kIOGeneralInterest,
            callback,
            selfPtr,
            &rootDomainNotifier
        )
        if kr != KERN_SUCCESS {
            print("[Lumos] Warning: Failed to register clamshell interest notification: \(kr)")
        }
        IOObjectRelease(rootDomain)
    }
    
    public func handleClamshellMessage() {
        let closed = checkIsLidClosed()
        if self.isLidClosed != closed {
            self.isLidClosed = closed
            print("[Lumos] MacBook lid state changed: closed = \(closed)")
            evaluateBacklightPowerState()
        }
    }
    
    public func checkIsLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        if let prop = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
            return prop
        }
        return false
    }
    
    public var maxAllowedBrightness: Double {
        let power = PowerManagementController.shared
        let settings = LumosSettings.shared
        
        if power.isLowPowerMode && settings.lowPowerModeDimEnabled {
            return 0.15
        } else if power.isOnBattery && settings.batteryOptimizationEnabled {
            return settings.batteryMaxBrightness
        }
        return 1.0
    }
    
    public func enforceMaxBrightnessLimit() {
        let maxVal = maxAllowedBrightness
        if brightness > maxVal {
            setBrightness(maxVal)
        } else if isOn && !isIdleDimmed && !isPowerSavingDimmed {
            applyBrightnessToHardware(brightness)
        }
    }
    
    public func evaluateBacklightPowerState() {
        guard LumosSettings.shared.sleepWithDisplayAndClamshell else {
            enforceMaxBrightnessLimit()
            return
        }
        let shouldTurnOff = isSystemSleeping || isScreenSleeping || isLidClosed
        
        if shouldTurnOff {
            stopAnimation()
            isPowerSavingDimmed = true
            applyBrightnessToHardware(0.0)
        } else {
            stopAnimation()
            isPowerSavingDimmed = false
            if isOn {
                enforceMaxBrightnessLimit()
                // Reset Touch Bar stage to active on wake
                if TouchBarController.isTouchBarAvailable {
                    TouchBarController.shared.updateTouchBarStage(.active)
                    touchBarSyncStage = .active
                    isIdleDimmed = false
                }
            }
        }
    }
    
    public func effectiveBrightness(for target: Double) -> Double {
        return min(target, maxAllowedBrightness)
    }
    
    // MARK: - Hardware Control
    
    public func applyBrightnessToHardware(_ normalized: Double) {
        if LumosSettings.shared.sleepWithDisplayAndClamshell && (isSystemSleeping || isScreenSleeping || isLidClosed) && normalized > 0.001 {
            print("[Lumos] Blocked hardware brightness \(normalized) because system/display is sleeping or lid is closed.")
            return
        }
        
        var effective = normalized
        if normalized > 0.001 && !isIdleDimmed && !isPowerSavingDimmed {
            effective = effectiveBrightness(for: normalized)
        }
        
        let rawVal = normalizedToRaw(effective)
        
        if directDevices.isEmpty {
            refreshDirectDevices()
        }
        
        // Exact WebHID Chromium macOS protocol: 9 bytes
        // byte 0: Report ID (1)
        // byte 1..4: brightness (UInt32 little-endian)
        // byte 5..8: duration (UInt32 little-endian)
        var buffer = [UInt8](repeating: 0, count: 9)
        buffer[0] = 1 // Report ID
        let bLE = UInt32(rawVal).littleEndian
        withUnsafeBytes(of: bLE) { p in
            for i in 0..<4 { buffer[1 + i] = p[i] }
        }
        let dLE = UInt32(0).littleEndian
        withUnsafeBytes(of: dLE) { p in
            for i in 0..<4 { buffer[5 + i] = p[i] }
        }
        
        var success = false
        for dev in directDevices {
            let ret = buffer.withUnsafeBytes { ptr -> IOReturn in
                guard let base = ptr.baseAddress else { return kIOReturnError }
                return IOHIDDeviceSetReport(
                    dev,
                    kIOHIDReportTypeFeature,
                    1,
                    base.assumingMemoryBound(to: UInt8.self),
                    buffer.count
                )
            }
            if ret == kIOReturnSuccess {
                success = true
            } else {
                print("[Lumos] IOHIDDeviceSetReport error: \(ret)")
            }
        }
        
        if success {
            print("[Lumos] Successfully set hardware brightness to \(rawVal)/512 (norm: \(String(format: "%.2f", normalized)))")
        } else {
            print("[Lumos] Failed to send report (devices: \(directDevices.count))")
        }
    }
    
    public func normalizedToRaw(_ normalized: Double) -> Int {
        if normalized <= 0.005 {
            return 0
        }
        let clamped = min(max(normalized, 0.0), 1.0)
        return Int(round(clamped * 512.0))
    }
    
    public func rawToNormalized(_ raw: Int) -> Double {
        if raw <= 0 { return 0.0 }
        return min(max(Double(raw) / 512.0, 0.0), 1.0)
    }
    
    private var animationTimer: Timer?
    
    public func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    // MARK: - User Actions
    
    public func togglePower() {
        stopAnimation()
        if isIdleDimmed {
            isIdleDimmed = false
        }
        
        if isOn {
            // Save last level and turn off
            LumosSettings.shared.lastActiveBrightness = max(brightness, 0.3)
            setBrightness(0.0)
        } else {
            // Restore last active level
            let restore = max(LumosSettings.shared.lastActiveBrightness, 0.3)
            setBrightness(restore)
        }
    }
    
    public func setBrightness(_ level: Double) {
        stopAnimation()
        if isIdleDimmed {
            isIdleDimmed = false
        }
        if touchBarSyncStage != .active {
            touchBarSyncStage = .active
        }
        let maxVal = maxAllowedBrightness
        brightness = min(max(level, 0.0), maxVal)
    }
    
    public func applyPreset(_ preset: Double) {
        stopAnimation()
        if isIdleDimmed {
            isIdleDimmed = false
        }
        if touchBarSyncStage != .active {
            touchBarSyncStage = .active
        }
        setBrightness(preset)
    }
    
    // MARK: - Native Keyboard Shortcut Stepping
    
    public func stepBrightnessUp(fine: Bool = false) {
        guard !isSystemSleeping && !isScreenSleeping && !isLidClosed else { return }
        stopAnimation()
        if isIdleDimmed {
            isIdleDimmed = false
        }
        if touchBarSyncStage != .active {
            touchBarSyncStage = .active
        }
        
        let step = fine ? (1.0 / 64.0) : (1.0 / 16.0)
        let newLevel = min(brightness + step, maxAllowedBrightness)
        setBrightness(newLevel)
        
        if LumosSettings.shared.showNativeOSDBezel {
            OSDBezelController.shared.showBacklightBezel(brightness: newLevel)
        }
    }
    
    public func stepBrightnessDown(fine: Bool = false) {
        guard !isSystemSleeping && !isScreenSleeping && !isLidClosed else { return }
        stopAnimation()
        if isIdleDimmed {
            isIdleDimmed = false
        }
        if touchBarSyncStage != .active {
            touchBarSyncStage = .active
        }
        
        let step = fine ? (1.0 / 64.0) : (1.0 / 16.0)
        let newLevel = max(brightness - step, 0.0)
        setBrightness(newLevel)
        
        if LumosSettings.shared.showNativeOSDBezel {
            OSDBezelController.shared.showBacklightBezel(brightness: newLevel)
        }
    }
    
    // MARK: - Touch Bar Sync Support (Dimming & Sleep)
    
    public func enterTouchBarDim(targetLevel: Double = 0.15) {
        guard !isSystemSleeping && !isScreenSleeping && !isLidClosed else { return }
        guard LumosSettings.shared.syncBacklightWithTouchBar else { return }
        guard isOn && touchBarSyncStage == .active else { return }
        stopAnimation()
        preDimBrightness = brightness
        touchBarSyncStage = .dimmed
        isIdleDimmed = true
        let clampedTarget = min(targetLevel, max(preDimBrightness * 0.5, 0.05))
        animateBrightness(from: brightness, to: clampedTarget, duration: 0.8)
    }
    
    public func enterTouchBarSleep() {
        guard LumosSettings.shared.syncBacklightWithTouchBar else { return }
        guard isOn && touchBarSyncStage != .sleeping else { return }
        stopAnimation()
        if touchBarSyncStage == .active {
            preDimBrightness = brightness
        }
        touchBarSyncStage = .sleeping
        isIdleDimmed = true
        
        if isSystemSleeping || isScreenSleeping || isLidClosed {
            applyBrightnessToHardware(0.0)
        } else {
            animateBrightness(from: brightness, to: 0.0, duration: 0.6)
        }
    }
    
    public func exitTouchBarSleep() {
        wakeTouchBarBacklight()
    }
    
    public func wakeTouchBarBacklight() {
        guard !isSystemSleeping && !isScreenSleeping && !isLidClosed else { return }
        guard touchBarSyncStage != .active else { return }
        stopAnimation()
        let startLevel = (touchBarSyncStage == .dimmed) ? LumosSettings.shared.touchBarDimLevel : 0.0
        touchBarSyncStage = .active
        isIdleDimmed = false
        let target = preDimBrightness > 0.01 ? preDimBrightness : (LumosSettings.shared.lastActiveBrightness > 0.01 ? LumosSettings.shared.lastActiveBrightness : 0.75)
        animateBrightness(from: startLevel, to: target, duration: 0.3)
    }
    
    public func enterIdleDim(targetLevel: Double = 0.0) {
        guard !isSystemSleeping && !isScreenSleeping && !isLidClosed else { return }
        guard LumosSettings.shared.autoDimEnabled else { return }
        guard isOn && !isIdleDimmed && touchBarSyncStage == .active else { return }
        stopAnimation()
        preDimBrightness = brightness
        isIdleDimmed = true
        animateBrightness(from: brightness, to: targetLevel, duration: 0.6)
    }
    
    public func exitIdleDim() {
        guard !isSystemSleeping && !isScreenSleeping && !isLidClosed else { return }
        guard isIdleDimmed && touchBarSyncStage == .active else { return }
        stopAnimation()
        isIdleDimmed = false
        animateBrightness(from: 0.0, to: preDimBrightness, duration: 0.3)
    }
    
    private func animateBrightness(from start: Double, to end: Double, duration: TimeInterval) {
        stopAnimation()
        
        if isSystemSleeping || isScreenSleeping || isLidClosed {
            applyBrightnessToHardware(0.0)
            return
        }
        
        guard abs(start - end) > 0.005 else {
            applyBrightnessToHardware(end)
            return
        }
        
        let steps = 12
        let stepInterval = duration / Double(steps)
        var currentStep = 0
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { timer.invalidate(); return }
                
                if self.isSystemSleeping || self.isScreenSleeping || self.isLidClosed {
                    self.stopAnimation()
                    self.applyBrightnessToHardware(0.0)
                    return
                }
                
                currentStep += 1
                let progress = Double(currentStep) / Double(steps)
                let current = start + (end - start) * progress
                
                self.isApplyingInternalState = true
                self.applyBrightnessToHardware(current)
                self.isApplyingInternalState = false
                
                if currentStep >= steps {
                    self.stopAnimation()
                    self.applyBrightnessToHardware(end)
                }
            }
        }
    }
}
