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
        
        let settingsView = LocalizedSettingsHostView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = NSLocalizedString("window_title_settings", comment: "")
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
}

private struct LocalizedSettingsHostView: View {
    @ObservedObject var settings = LumosSettings.shared
    
    var body: some View {
        SettingsView()
            .environment(\.locale, settings.appLanguage.effectiveLocale)
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Keep window reference for quick re-display
    }
}
