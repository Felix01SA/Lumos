//
//  TouchBarView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import AppKit
import SwiftUI

public struct TouchBarView: View {
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var settings: LumosSettings
    
    @MainActor
    public init() {
        self.engine = .shared
        self.settings = .shared
    }
    
    public init(engine: KeyboardBacklightEngine, settings: LumosSettings) {
        self.engine = engine
        self.settings = settings
    }
    
    public var body: some View {
        TouchBarAccessorRepresentable()
            .frame(width: 0, height: 0)
    }
}

struct TouchBarAccessorRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> TouchBarAccessorNSView {
        return TouchBarAccessorNSView()
    }
    
    func updateNSView(_ nsView: TouchBarAccessorNSView, context: Context) {
        nsView.attachTouchBarIfNeeded()
    }
}

class TouchBarAccessorNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachTouchBarIfNeeded()
    }
    
    func attachTouchBarIfNeeded() {
        guard let win = window else { return }
        if win.touchBar == nil {
            win.touchBar = TouchBarController.shared.makeTouchBar()
        }
    }
    
    override func makeTouchBar() -> NSTouchBar? {
        return TouchBarController.shared.makeTouchBar()
    }
}

#if DEBUG
#Preview {
    TouchBarView()
}
#endif

