//
//  LaunchAtLoginManager.swift
//  Lumos
//
//  Created by Felix Almeida on 25/09/26.
//

import Foundation
import ServiceManagement
import Combine
import AppKit

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var requiresApproval: Bool = false
    
    private let service = SMAppService.mainApp
    
    public init() {
        refreshStatus()
    }
    
    public func refreshStatus() {
        switch service.status {
        case .enabled:
            self.isEnabled = true
            self.requiresApproval = false
        case .requiresApproval:
            self.isEnabled = false
            self.requiresApproval = true
        case .notRegistered, .notFound:
            fallthrough
        @unknown default:
            self.isEnabled = false
            self.requiresApproval = false
        }
    }
    
    public func setEnabled(_ enable: Bool) {
        do {
            if enable {
                if service.status == .enabled { return }
                try service.register()
            } else {
                if service.status == .notRegistered { return }
                try service.unregister()
            }
        } catch {
            print("[Lumos] Failed to update Launch at Login: \(error.localizedDescription)")
        }
        refreshStatus()
    }
    
    public func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
