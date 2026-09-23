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
    @Published public private(set) var isBreathing: Bool = false
    @Published public private(set) var isIdleDimmed: Bool = false
    @Published public private(set) var touchBarSyncStage: TouchBarController.TouchBarDisplayStage = .active
    
    public var isTouchBarSleeping: Bool {
        touchBarSyncStage == .sleeping
    }
    
    public var isTouchBarDimmed: Bool {
        touchBarSyncStage == .dimmed
    }
    
    @Published public var brightness: Double = 0.75 {
        didSet {
            let clamped = min(max(brightness, 0.0), 1.0)
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
    private var breathingTimer: Timer?
    private var breathingAngle: Double = 0.0
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
        breathingTimer?.invalidate()
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
    
    // MARK: - Sleep & Wake Listeners
    
    private func setupSleepWakeListeners() {
        // macOS resets keyboard backlight to 0 when sleeping. Restore on wake!
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    print("[Lumos] Mac woke up from sleep. Restoring backlight...")
                    self.refreshDirectDevices()
                    if self.isOn {
                        self.applyBrightnessToHardware(self.brightness)
                    }
                }
            }
            .store(in: &cancellables)
        
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.isOn {
                        self.applyBrightnessToHardware(self.brightness)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Hardware Control
    
    public func applyBrightnessToHardware(_ normalized: Double) {
        let rawVal = normalizedToRaw(normalized)
        
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
    
    // MARK: - User Actions
    
    public func togglePower() {
        if isBreathing {
            stopBreathingEffect()
        }
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
        if isBreathing {
            stopBreathingEffect()
        }
        if isIdleDimmed {
            isIdleDimmed = false
        }
        if touchBarSyncStage != .active {
            touchBarSyncStage = .active
        }
        brightness = min(max(level, 0.0), 1.0)
    }
    
    public func applyPreset(_ preset: Double) {
        if isBreathing {
            stopBreathingEffect()
        }
        if isIdleDimmed {
            isIdleDimmed = false
        }
        if touchBarSyncStage != .active {
            touchBarSyncStage = .active
        }
        setBrightness(preset)
    }
    
    // MARK: - Touch Bar Sync Support (Dimming & Sleep)
    
    public func enterTouchBarDim(targetLevel: Double = 0.15) {
        guard LumosSettings.shared.syncBacklightWithTouchBar else { return }
        guard isOn && !isBreathing && touchBarSyncStage == .active else { return }
        preDimBrightness = brightness
        touchBarSyncStage = .dimmed
        isIdleDimmed = true
        let clampedTarget = min(targetLevel, max(preDimBrightness * 0.5, 0.05))
        animateBrightness(from: brightness, to: clampedTarget, duration: 0.8)
    }
    
    public func enterTouchBarSleep() {
        guard LumosSettings.shared.syncBacklightWithTouchBar else { return }
        guard isOn && !isBreathing && touchBarSyncStage != .sleeping else { return }
        if touchBarSyncStage == .active {
            preDimBrightness = brightness
        }
        touchBarSyncStage = .sleeping
        isIdleDimmed = true
        animateBrightness(from: brightness, to: 0.0, duration: 0.6)
    }
    
    public func exitTouchBarSleep() {
        wakeTouchBarBacklight()
    }
    
    public func wakeTouchBarBacklight() {
        guard touchBarSyncStage != .active else { return }
        touchBarSyncStage = .active
        isIdleDimmed = false
        animateBrightness(from: brightness, to: preDimBrightness, duration: 0.3)
    }
    
    public func enterIdleDim(targetLevel: Double = 0.0) {
        guard LumosSettings.shared.autoDimEnabled else { return }
        guard isOn && !isIdleDimmed && !isBreathing && touchBarSyncStage == .active else { return }
        preDimBrightness = brightness
        isIdleDimmed = true
        animateBrightness(from: brightness, to: targetLevel, duration: 0.6)
    }
    
    public func exitIdleDim() {
        guard isIdleDimmed && touchBarSyncStage == .active else { return }
        isIdleDimmed = false
        animateBrightness(from: brightness, to: preDimBrightness, duration: 0.3)
    }
    
    private func animateBrightness(from start: Double, to end: Double, duration: TimeInterval) {
        let steps = 15
        let stepInterval = duration / Double(steps)
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { timer.invalidate(); return }
                currentStep += 1
                let progress = Double(currentStep) / Double(steps)
                let current = start + (end - start) * progress
                
                self.isApplyingInternalState = true
                self.brightness = current
                self.applyBrightnessToHardware(current)
                self.isApplyingInternalState = false
                
                if currentStep >= steps {
                    timer.invalidate()
                    self.brightness = end
                    self.applyBrightnessToHardware(end)
                }
            }
        }
    }
    
    // MARK: - Breathing Mode (Ambient Pulse)
    
    public func toggleBreathingEffect() {
        if isBreathing {
            stopBreathingEffect()
        } else {
            startBreathingEffect()
        }
    }
    
    public func startBreathingEffect() {
        guard isHardwareAvailable else { return }
        isBreathing = true
        breathingAngle = 0.0
        
        breathingTimer?.invalidate()
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isBreathing else { return }
                self.breathingAngle += 0.06
                if self.breathingAngle > .pi * 2 {
                    self.breathingAngle -= .pi * 2
                }
                
                // Sinusoidal wave between 0.05 and 0.90
                let sinVal = (sin(self.breathingAngle) + 1.0) / 2.0
                let waveLevel = 0.05 + (sinVal * 0.85)
                
                self.isApplyingInternalState = true
                self.brightness = waveLevel
                self.applyBrightnessToHardware(waveLevel)
                self.isApplyingInternalState = false
            }
        }
    }
    
    public func stopBreathingEffect() {
        guard isBreathing else { return }
        isBreathing = false
        breathingTimer?.invalidate()
        breathingTimer = nil
        
        // Restore last active brightness
        let restore = LumosSettings.shared.lastActiveBrightness
        setBrightness(restore)
    }
}
