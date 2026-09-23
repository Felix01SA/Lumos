//
//  IdleActivityMonitor.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import Foundation
import CoreGraphics
import Combine
import AppKit
import notify

@MainActor
public final class IdleActivityMonitor: ObservableObject {
    public static let shared = IdleActivityMonitor()
    
    @Published public private(set) var idleSeconds: Double = 0.0
    @Published public private(set) var isCurrentlyIdle: Bool = false
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var touchBarStateToken: Int32 = 0
    private var dfrStatusToken: Int32 = 0
    
    private let engine: KeyboardBacklightEngine
    private let settings: LumosSettings
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
        startMonitoring()
        setupTouchBarStateObserver()
        setupWorkspaceNotifications()
    }
    
    public init(engine: KeyboardBacklightEngine, settings: LumosSettings) {
        self.engine = engine
        self.settings = settings
        startMonitoring()
        setupTouchBarStateObserver()
        setupWorkspaceNotifications()
    }
    
    deinit {
        timer?.invalidate()
        if touchBarStateToken != 0 {
            notify_cancel(touchBarStateToken)
        }
        if dfrStatusToken != 0 {
            notify_cancel(dfrStatusToken)
        }
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkActivity()
            }
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Touch Bar Lifecycle Observer (Darwin & DFRFoundation)
    
    private func setupTouchBarStateObserver() {
        guard TouchBarController.isTouchBarAvailable else { return }
        
        // Instant event-driven notification from macOS TouchBarServer
        notify_register_dispatch("com.apple.system.touchbarserver.state", &touchBarStateToken, DispatchQueue.main) { [weak self] token in
            Task { @MainActor [weak self] in
                self?.handleTouchBarStateChange(token: token)
            }
        }
        
        notify_register_dispatch("com.apple.DFRFoundation.status", &dfrStatusToken, DispatchQueue.main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateTouchBarStatus()
            }
        }
    }
    
    private func handleTouchBarStateChange(token: Int32) {
        var state: UInt64 = 0
        notify_get_state(token, &state)
        
        // state == 1: Active / Awake
        // state == 5 (or other non-1): Inactive / Asleep
        if state == 1 {
            TouchBarController.shared.updateTouchBarStage(.active)
            if settings.syncBacklightWithTouchBar {
                engine.wakeTouchBarBacklight()
            }
        } else {
            TouchBarController.shared.updateTouchBarStage(.sleeping)
            if settings.syncBacklightWithTouchBar {
                engine.enterTouchBarSleep()
            }
        }
    }
    
    private func evaluateTouchBarStatus() {
        let status = TouchBarController.getTouchBarStatus()
        guard status != -1 else { return }
        if status == 5 {
            TouchBarController.shared.updateTouchBarStage(.sleeping)
            if settings.syncBacklightWithTouchBar {
                engine.enterTouchBarSleep()
            }
        } else if status == 1 {
            TouchBarController.shared.updateTouchBarStage(.active)
            if settings.syncBacklightWithTouchBar {
                engine.wakeTouchBarBacklight()
            }
        }
    }
    
    private func setupWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.settings.syncBacklightWithTouchBar && TouchBarController.isTouchBarAvailable {
                        TouchBarController.shared.updateTouchBarStage(.sleeping)
                        self.engine.enterTouchBarSleep()
                    }
                }
            }
            .store(in: &cancellables)
            
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.settings.syncBacklightWithTouchBar && TouchBarController.isTouchBarAvailable {
                        TouchBarController.shared.updateTouchBarStage(.active)
                        self.engine.wakeTouchBarBacklight()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Periodic HID Activity Evaluation
    
    private func checkActivity() {
        guard let anyEvent = CGEventType(rawValue: ~0) else { return }
        let elapsed = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyEvent)
        self.idleSeconds = elapsed
        
        // Touch Bar 2-stage synchronization (Dimming at ~60s, Sleep at ~75s, Wake upon user input)
        if settings.syncBacklightWithTouchBar && TouchBarController.isTouchBarAvailable {
            if elapsed < 1.0 {
                // User interacted with Mac: instantly restore full active brightness
                if engine.touchBarSyncStage != .active {
                    TouchBarController.shared.updateTouchBarStage(.active)
                    engine.wakeTouchBarBacklight()
                }
            } else if elapsed >= settings.touchBarSleepSeconds {
                // Stage 2: Touch Bar turns off completely (~75s) -> turn off keyboard backlight
                if engine.touchBarSyncStage != .sleeping {
                    TouchBarController.shared.updateTouchBarStage(.sleeping)
                    engine.enterTouchBarSleep()
                }
            } else if elapsed >= settings.touchBarDimSeconds {
                // Stage 1: Touch Bar dims due to inactivity (~60s) -> dim keyboard backlight!
                if engine.touchBarSyncStage == .active {
                    TouchBarController.shared.updateTouchBarStage(.dimmed)
                    engine.enterTouchBarDim(targetLevel: settings.touchBarDimLevel)
                }
            }
            
            // Backup check against DFR status
            let dfrStatus = TouchBarController.getTouchBarStatus()
            if dfrStatus == 5 && engine.touchBarSyncStage != .sleeping {
                TouchBarController.shared.updateTouchBarStage(.sleeping)
                engine.enterTouchBarSleep()
            } else if dfrStatus == 1 && engine.touchBarSyncStage != .active && elapsed < 2.0 {
                TouchBarController.shared.updateTouchBarStage(.active)
                engine.wakeTouchBarBacklight()
            }
        }
        
        // Generic auto-dim check (timer-based if enabled)
        guard settings.autoDimEnabled else {
            if isCurrentlyIdle {
                isCurrentlyIdle = false
                engine.exitIdleDim()
            }
            return
        }
        
        let threshold = settings.autoDimSeconds
        if elapsed >= threshold {
            if !isCurrentlyIdle {
                isCurrentlyIdle = true
                engine.enterIdleDim(targetLevel: settings.dimLevel)
            }
        } else {
            if isCurrentlyIdle {
                isCurrentlyIdle = false
                engine.exitIdleDim()
            }
        }
    }
}
