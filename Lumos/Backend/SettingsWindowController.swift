//
//  SettingsWindowController.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    public func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(settings: .shared, engine: .shared)
        let hostingView = NSHostingView(rootView: settingsView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 535),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Ajustes do Lumos"
        win.titleVisibility = .visible
        win.titlebarAppearsTransparent = false
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.touchBar = TouchBarController.shared.makeTouchBar()
        self.window = win
        
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Keep window reference for quick re-display
    }
}
