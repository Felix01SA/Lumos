//
//  PowerManagementController.swift
//  Lumos
//
//  Created by Felix Almeida on 25/09/26.
//

import Foundation
import AppKit
import Combine
import IOKit.ps
import notify

@MainActor
public final class PowerManagementController: ObservableObject {
    public static let shared = PowerManagementController()
    
    @Published public private(set) var isOnBattery: Bool = false
    @Published public private(set) var batteryPercent: Int = 100
    @Published public private(set) var isCharging: Bool = false
    @Published public private(set) var isLowPowerMode: Bool = false
    
    private var powerNotifyToken: Int32 = 0
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        refreshPowerState()
        setupListeners()
    }
    
    deinit {
        if powerNotifyToken != 0 {
            notify_cancel(powerNotifyToken)
        }
    }
    
    public func refreshPowerState() {
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            self.isOnBattery = false
            return
        }
        
        var foundBattery = false
        for s in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, s)?.takeUnretainedValue() as? [String: Any] {
                let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
                let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
                let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
                
                if currentCapacity >= 0 {
                    self.batteryPercent = currentCapacity
                }
                self.isCharging = charging
                
                if state == kIOPSBatteryPowerValue {
                    self.isOnBattery = true
                    foundBattery = true
                }
            }
        }
        if !foundBattery {
            self.isOnBattery = false
        }
    }
    
    private func setupListeners() {
        // Darwin notification for power source transitions (AC <-> Battery)
        notify_register_dispatch("com.apple.system.powersources.source", &powerNotifyToken, DispatchQueue.main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.refreshPowerState()
                KeyboardBacklightEngine.shared.evaluateBacklightPowerState()
            }
        }
        
        // Low Power Mode notification
        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.refreshPowerState()
                    KeyboardBacklightEngine.shared.evaluateBacklightPowerState()
                }
            }
            .store(in: &cancellables)
    }
}
