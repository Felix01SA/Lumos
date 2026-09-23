//
//  TouchBarController.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import AppKit
import SwiftUI
import Combine

private typealias DFRElementSetControlStripPresenceForIdentifierType = @convention(c) (CFString, DarwinBoolean) -> Void
private typealias DFRSystemModalShowsCloseBoxWhenExpandedType = @convention(c) (DarwinBoolean) -> Void

// MARK: - Square Touch Bar Button (Intrinsic Content Sizing, Zero Layout Conflicts)

public class SquareTouchBarButton: NSButton {
    public var customWidth: CGFloat = 44.0
    
    public override var intrinsicContentSize: NSSize {
        let natural = super.intrinsicContentSize
        let w = max(natural.width + 12.0, customWidth)
        return NSSize(width: w, height: 30.0)
    }
    
    public var isActive: Bool = false {
        didSet { updateAppearance() }
    }
    
    public override var isHighlighted: Bool {
        didSet { updateAppearance() }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    public convenience init(title: String, target: AnyObject?, action: Selector?, customWidth: CGFloat = 56.0) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.customWidth = customWidth
        self.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
    }
    
    public convenience init(image: NSImage, target: AnyObject?, action: Selector?, customWidth: CGFloat = 44.0) {
        self.init(frame: .zero)
        self.image = image
        self.target = target
        self.action = action
        self.customWidth = customWidth
    }
    
    private func setup() {
        isBordered = false
        wantsLayer = true
        // Subtle 4px corner radius matching physical Mac keys and Control Strip tiles
        layer?.cornerRadius = 4.0
        layer?.masksToBounds = true
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isActive {
            layer?.backgroundColor = isHighlighted
                ? NSColor.controlAccentColor.cgColor
                : NSColor.controlAccentColor.cgColor
        } else {
            layer?.backgroundColor = isHighlighted
                ? NSColor(white: 0.38, alpha: 1.0).cgColor
                : NSColor(white: 0.25, alpha: 1.0).cgColor
        }
    }
}

// MARK: - Touch Bar Controller

@MainActor
public final class TouchBarController: NSObject, ObservableObject, NSTouchBarDelegate {
    public static let shared = TouchBarController()
    
    // Identifiers
    private let controlStripIdentifier = NSTouchBarItem.Identifier("dev.felix01sa.lumos.controlstrip")
    
    public static let powerId = NSTouchBarItem.Identifier("dev.felix01sa.lumos.power")
    public static let sliderId = NSTouchBarItem.Identifier("dev.felix01sa.lumos.slider")
    public static let preset0Id = NSTouchBarItem.Identifier("dev.felix01sa.lumos.preset.0")
    public static let preset25Id = NSTouchBarItem.Identifier("dev.felix01sa.lumos.preset.25")
    public static let preset50Id = NSTouchBarItem.Identifier("dev.felix01sa.lumos.preset.50")
    public static let preset75Id = NSTouchBarItem.Identifier("dev.felix01sa.lumos.preset.75")
    public static let preset100Id = NSTouchBarItem.Identifier("dev.felix01sa.lumos.preset.100")
    public static let breathingId = NSTouchBarItem.Identifier("dev.felix01sa.lumos.breathing")
    
    // Hardware Touch Bar availability & status
    nonisolated public static let isTouchBarAvailable: Bool = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW) else {
            return false
        }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "DFRGetScreenSize") else { return false }
        let getSize = unsafeBitCast(sym, to: (@convention(c) () -> CGSize).self)
        let size = getSize()
        return size.width > 0
    }()
    
    nonisolated public static func getTouchBarStatus() -> Int32 {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW) else {
            return -1
        }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "DFRGetStatus") else { return -1 }
        let getStatus = unsafeBitCast(sym, to: (@convention(c) () -> Int32).self)
        return getStatus()
    }
    
    public enum TouchBarDisplayStage: String, CaseIterable {
        case active = "Ativa"
        case dimmed = "Esmaecida"
        case sleeping = "Em repouso"
    }
    
    @Published public private(set) var displayStage: TouchBarDisplayStage = .active
    
    public var isTouchBarAsleep: Bool {
        displayStage == .sleeping
    }
    
    public var isTouchBarDimmed: Bool {
        displayStage == .dimmed
    }
    
    public func updateTouchBarStage(_ stage: TouchBarDisplayStage) {
        if displayStage != stage {
            displayStage = stage
        }
    }
    
    public func updateTouchBarSleepState(asleep: Bool) {
        updateTouchBarStage(asleep ? .sleeping : .active)
    }
    
    public var systemTouchBar: NSTouchBar?
    private var controlStripItem: NSCustomTouchBarItem?
    private var cancellables = Set<AnyCancellable>()
    
    // Live UI element caches for syncing state
    private var powerButtons: [NSButton] = []
    private var sliders: [NSSlider] = []
    private var presetButtons: [Int: [NSButton]] = [:]
    private var breathingButtons: [NSButton] = []
    
    private let engine: KeyboardBacklightEngine
    private let settings: LumosSettings
    
    @MainActor
    public override init() {
        self.engine = .shared
        self.settings = .shared
        super.init()
        
        self.systemTouchBar = makeTouchBar()
        setupControlStrip()
        observeSettings()
        observeEngine()
        setupWindowKeyObserver()
    }
    
    // MARK: - Native TouchBar Factory
    
    public func makeTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            Self.powerId,
            Self.sliderId,
            Self.preset0Id,
            Self.preset25Id,
            Self.preset50Id,
            Self.preset75Id,
            Self.preset100Id,
        ]
        return bar
    }
    
    // MARK: - NSTouchBarDelegate (Square Control Strip Tile Controls)
    
    public func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case Self.powerId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let btn = NSButton(
                image: NSImage(systemSymbolName: engine.isOn ? "lightbulb.fill" : "lightbulb.slash", accessibilityDescription: "Ligar / Desligar") ?? NSImage(),
                target: self,
                action: #selector(powerTapped),
            )
            btn.contentTintColor = engine.isOn ? .systemYellow : .secondaryLabelColor
            powerButtons.append(btn)
            item.view = btn
            return item
            
        case Self.sliderId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 6
            stack.alignment = .centerY
            
            if let minImg = NSImage(systemSymbolName: "sun.min.fill", accessibilityDescription: "Mínimo") {
                let iv = NSImageView(image: minImg)
                iv.contentTintColor = .secondaryLabelColor
                stack.addArrangedSubview(iv)
            }
            
            let sl = NSSlider(value: engine.brightness, minValue: 0.0, maxValue: 1.0, target: self, action: #selector(sliderChanged(_:)))
            sl.isContinuous = true
            let wConstraint = sl.widthAnchor.constraint(equalToConstant: 140)
            wConstraint.priority = .defaultHigh
            wConstraint.isActive = true
            sliders.append(sl)
            stack.addArrangedSubview(sl)
            
            if let maxImg = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Máximo") {
                let iv = NSImageView(image: maxImg)
                iv.contentTintColor = .secondaryLabelColor
                stack.addArrangedSubview(iv)
            }
            
            item.view = stack
            return item
            
        case Self.preset0Id:
            return makePresetItem(identifier: identifier, title: "0%", value: 0.0)
        case Self.preset25Id:
            return makePresetItem(identifier: identifier, title: "25%", value: 0.25)
        case Self.preset50Id:
            return makePresetItem(identifier: identifier, title: "50%", value: 0.50)
        case Self.preset75Id:
            return makePresetItem(identifier: identifier, title: "75%", value: 0.75)
        case Self.preset100Id:
            return makePresetItem(identifier: identifier, title: "100%", value: 1.0)
            
        default:
            return nil
        }
    }
    
    private func makePresetItem(identifier: NSTouchBarItem.Identifier, title: String, value: Double) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let percent = Int(round(value * 100))
        let btn = NSButton(
            title: title,
            target: self,
            action: #selector(presetClicked(_:)),
        )
        btn.tag = percent
        
        let isActive = abs(engine.brightness - value) < 0.04 && engine.isOn
        btn.bezelColor = isActive ? .controlAccentColor : .controlBackgroundColor
        
        var list = presetButtons[percent] ?? []
        list.append(btn)
        presetButtons[percent] = list
        
        item.view = btn
        return item
    }
    
    // MARK: - Actions
    
    @objc private func powerTapped() {
        engine.togglePower()
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        engine.setBrightness(sender.doubleValue)
    }
    
    @objc private func presetClicked(_ sender: NSButton) {
        let val = Double(sender.tag) / 100.0
        engine.applyPreset(val)
    }
    
    @objc private func breathingTapped() {
        engine.toggleBreathingEffect()
    }
    
    // MARK: - State Synchronization
    
    private func observeEngine() {
        engine.$brightness
            .receive(on: DispatchQueue.main)
            .sink { [weak self] b in
                guard let self = self else { return }
                for sl in self.sliders {
                    if abs(sl.doubleValue - b) > 0.005 {
                        sl.doubleValue = b
                    }
                }
                self.updatePresetButtonHighlights(currentBrightness: b, isOn: self.engine.isOn)
            }
            .store(in: &cancellables)
            
        engine.$isOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] on in
                guard let self = self else { return }
                for btn in self.powerButtons {
                    btn.image = NSImage(systemSymbolName: on ? "lightbulb.fill" : "lightbulb.slash", accessibilityDescription: "Power")
                    btn.contentTintColor = on ? .systemYellow : .secondaryLabelColor
                }
                self.updatePresetButtonHighlights(currentBrightness: self.engine.brightness, isOn: on)
            }
            .store(in: &cancellables)
            
        engine.$isBreathing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] breathing in
                guard let self = self else { return }
                for btn in self.breathingButtons {
                    if let squareBtn = btn as? SquareTouchBarButton {
                        squareBtn.isActive = breathing
                    } else {
                        btn.bezelColor = breathing ? .controlAccentColor : nil
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updatePresetButtonHighlights(currentBrightness: Double, isOn: Bool) {
        for (percent, buttons) in presetButtons {
            let targetVal = Double(percent) / 100.0
            let isActive = abs(currentBrightness - targetVal) < 0.04 && isOn
            for btn in buttons {
                if let squareBtn = btn as? SquareTouchBarButton {
                    squareBtn.isActive = isActive
                } else {
                    btn.bezelColor = isActive ? .controlAccentColor : nil
                }
            }
        }
    }
    
    // MARK: - Window Key Observer
    
    private func setupWindowKeyObserver() {
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] notif in
                guard let self = self, let win = notif.object as? NSWindow else { return }
                if win.touchBar == nil {
                    win.touchBar = self.makeTouchBar()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Control Strip Integration (Square Flat System Tray Item)
    
    private func setupControlStrip() {
        guard settings.showInTouchBarControlStrip else { return }
        
        let dfrHandle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)
        if let handle = dfrHandle {
            if let sym = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") {
                let setPresence = unsafeBitCast(sym, to: DFRElementSetControlStripPresenceForIdentifierType.self)
                setPresence(controlStripIdentifier.rawValue as CFString, true)
            }
            if let sym2 = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenExpanded") {
                let setShowClose = unsafeBitCast(sym2, to: DFRSystemModalShowsCloseBoxWhenExpandedType.self)
                setShowClose(true)
            }
            dlclose(handle)
        }
        
        let item = NSCustomTouchBarItem(identifier: controlStripIdentifier)
        let button = SquareTouchBarButton(
            image: NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Lumos Backlight") ?? NSImage(),
            target: self,
            action: #selector(controlStripButtonTapped),
            customWidth: 40.0
        )
        
        button.bezelColor = .controlBackgroundColor
        
        item.view = button
        self.controlStripItem = item
        
        let selAdd = NSSelectorFromString("addSystemTrayItem:")
        if NSTouchBarItem.responds(to: selAdd) {
            _ = NSTouchBarItem.perform(selAdd, with: item)
        }
    }
    
    @objc private func controlStripButtonTapped() {
        guard let bar = systemTouchBar else { return }
        let selPresent = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        if NSTouchBar.responds(to: selPresent) {
            _ = NSTouchBar.perform(selPresent, with: bar, with: controlStripIdentifier)
        }
    }
    
    public func dismissModal() {
        guard let bar = systemTouchBar else { return }
        let selDismiss = NSSelectorFromString("minimizeSystemModalTouchBar:")
        if NSTouchBar.responds(to: selDismiss) {
            _ = NSTouchBar.perform(selDismiss, with: bar)
        }
    }
    
    private func observeSettings() {
        settings.$showInTouchBarControlStrip
            .sink { [weak self] enabled in
                Task { @MainActor [weak self] in
                    if enabled {
                        self?.setupControlStrip()
                    } else {
                        self?.removeControlStrip()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func removeControlStrip() {
        let dfrHandle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)
        if let handle = dfrHandle {
            if let sym = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") {
                let setPresence = unsafeBitCast(sym, to: DFRElementSetControlStripPresenceForIdentifierType.self)
                setPresence(controlStripIdentifier.rawValue as CFString, false)
            }
            dlclose(handle)
        }
    }
}
