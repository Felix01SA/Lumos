//
//  ExternalKeyboardMonitor.swift
//  Lumos
//
//  Created by Felix Almeida on 25/09/26.
//

import Foundation
import AppKit
import Combine
import IOKit
import IOKit.hid

@MainActor
public final class ExternalKeyboardMonitor: ObservableObject {
    public static let shared = ExternalKeyboardMonitor()
    
    @Published public private(set) var hasExternalKeyboard: Bool = false
    @Published public private(set) var externalKeyboardName: String = ""
    @Published public private(set) var connectedKeyboards: [String] = []
    
    private var notifyPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    
    public init() {
        setupIORegistryMonitor()
        refreshConnectedKeyboards()
    }
    
    deinit {
        if let port = notifyPort {
            IONotificationPortDestroy(port)
        }
        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
        }
        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
        }
    }
    
    private func setupIORegistryMonitor() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        self.notifyPort = port
        
        if let runLoopSrc = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSrc, .defaultMode)
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let matchedCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon = refcon else { return }
            let monitor = Unmanaged<ExternalKeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            while case let service = IOIteratorNext(iterator), service != 0 {
                IOObjectRelease(service)
            }
            Task { @MainActor in
                monitor.refreshConnectedKeyboards()
            }
        }
        
        let terminatedCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon = refcon else { return }
            let monitor = Unmanaged<ExternalKeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            while case let service = IOIteratorNext(iterator), service != 0 {
                IOObjectRelease(service)
            }
            Task { @MainActor in
                monitor.refreshConnectedKeyboards()
            }
        }
        
        let match1 = IOServiceMatching("IOHIDDevice") as NSMutableDictionary
        match1[kIOHIDPrimaryUsagePageKey] = 0x01
        match1[kIOHIDPrimaryUsageKey] = 0x06
        
        let match2 = IOServiceMatching("IOHIDDevice") as NSMutableDictionary
        match2[kIOHIDPrimaryUsagePageKey] = 0x01
        match2[kIOHIDPrimaryUsageKey] = 0x06
        
        let kr1 = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            match1,
            matchedCallback,
            selfPtr,
            &matchedIterator
        )
        if kr1 == KERN_SUCCESS {
            while case let s = IOIteratorNext(matchedIterator), s != 0 {
                IOObjectRelease(s)
            }
        }
        
        let kr2 = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            match2,
            terminatedCallback,
            selfPtr,
            &terminatedIterator
        )
        if kr2 == KERN_SUCCESS {
            while case let s = IOIteratorNext(terminatedIterator), s != 0 {
                IOObjectRelease(s)
            }
        }
    }
    
    public func refreshConnectedKeyboards() {
        let matching = IOServiceMatching("IOHIDDevice") as NSMutableDictionary
        matching[kIOHIDPrimaryUsagePageKey] = 0x01
        matching[kIOHIDPrimaryUsageKey] = 0x06
        
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        
        var detectedExternals: [String] = []
        
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            
            if let prod = IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                let lower = prod.lowercased()
                
                // Ignorar teclado interno do MacBook, Touch Bar e drivers virtuais
                if lower.contains("internal") ||
                   lower.contains("touchbar") ||
                   lower.contains("touch bar") ||
                   lower.contains("virtual") ||
                   lower.contains("karabiner") ||
                   lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                if !detectedExternals.contains(prod) {
                    detectedExternals.append(prod)
                }
            }
        }
        
        self.connectedKeyboards = detectedExternals
        let hadExternal = self.hasExternalKeyboard
        self.hasExternalKeyboard = !detectedExternals.isEmpty
        self.externalKeyboardName = detectedExternals.first ?? ""
        
        if hadExternal != self.hasExternalKeyboard {
            print("[Lumos] External keyboard state changed: connected = \(self.hasExternalKeyboard) (\(self.externalKeyboardName))")
            KeyboardBacklightEngine.shared.evaluateBacklightPowerState()
        }
    }
}
