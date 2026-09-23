//
//  IdleActivityMonitor.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import Foundation
import CoreGraphics
import Combine

@MainActor
public final class IdleActivityMonitor: ObservableObject {
    public static let shared = IdleActivityMonitor()
    
    @Published public private(set) var idleSeconds: Double = 0.0
    @Published public private(set) var isCurrentlyIdle: Bool = false
    
    private var timer: Timer?
    private let engine: KeyboardBacklightEngine
    private let settings: LumosSettings
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
        startMonitoring()
    }
    
    public init(engine: KeyboardBacklightEngine, settings: LumosSettings) {
        self.engine = engine
        self.settings = settings
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
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
    
    private func checkActivity() {
        guard let anyEvent = CGEventType(rawValue: ~0) else { return }
        let elapsed = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyEvent)
        self.idleSeconds = elapsed
        
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
