//
//  SettingsSheetView.swift
//  Lumos
//
//  Created by Felix Almeida on 23/09/26.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: LumosSettings
    @ObservedObject var engine: KeyboardBacklightEngine
    @ObservedObject var touchBar: TouchBarController
    @ObservedObject var monitor: IdleActivityMonitor
    @ObservedObject var shortcuts: KeyboardShortcutManager
    @ObservedObject var launchManager: LaunchAtLoginManager
    @ObservedObject var power: PowerManagementController
    @ObservedObject var externalKeyboard: ExternalKeyboardMonitor
    
    @MainActor
    public init() {
        self.settings = .shared
        self.engine = .shared
        self.touchBar = .shared
        self.monitor = .shared
        self.shortcuts = .shared
        self.launchManager = .shared
        self.power = .shared
        self.externalKeyboard = .shared
    }
    
    @MainActor
    public init(settings: LumosSettings, engine: KeyboardBacklightEngine) {
        self.settings = settings
        self.engine = engine
        self.touchBar = .shared
        self.monitor = .shared
        self.shortcuts = .shared
        self.launchManager = .shared
        self.power = .shared
        self.externalKeyboard = .shared
    }
    
    @MainActor
    public init(settings: LumosSettings, engine: KeyboardBacklightEngine, touchBar: TouchBarController) {
        self.settings = settings
        self.engine = engine
        self.touchBar = touchBar
        self.monitor = .shared
        self.shortcuts = .shared
        self.launchManager = .shared
        self.power = .shared
        self.externalKeyboard = .shared
    }
    
    @MainActor
    public init(
        settings: LumosSettings,
        engine: KeyboardBacklightEngine,
        touchBar: TouchBarController,
        monitor: IdleActivityMonitor,
        shortcuts: KeyboardShortcutManager
    ) {
        self.settings = settings
        self.engine = engine
        self.touchBar = touchBar
        self.monitor = monitor
        self.shortcuts = shortcuts
        self.launchManager = .shared
        self.power = .shared
        self.externalKeyboard = .shared
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.8), Color.yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .shadow(color:engine.isOn ? Color.orange.opacity(0.4) : .clear, radius: 4)
                        
                        Image("icon").resizable().frame(width: 50, height: 50)
//                            .font(.system(size: 18, weight: .bold))
//                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("app_name")
                            .font(.title3.weight(.bold))
                        Text("app_subtitle_settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 2)
                
                Divider()
                
                // Section: Interface & Menus
                VStack(alignment: .leading, spacing: 10) {
                    Label("settings_section_menubar", systemImage: "menubar.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Toggle("settings_show_percentage", isOn: $settings.showPercentageInMenuBar)
                        .toggleStyle(.checkbox)
                    
                    Toggle("settings_launch_at_login", isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    ))
                    .toggleStyle(.checkbox)
                    
                    if launchManager.requiresApproval {
                        Button {
                            launchManager.openSystemSettingsLoginItems()
                        } label: {
                            Label("launch_at_login_status_requires_approval", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.link)
                        .padding(.leading, 18)
                    }
                    
                    HStack(spacing: 8) {
                        Text("settings_language_label")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $settings.appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 170)
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Section: Inactivity Timer (ActivityControlView)
                VStack(alignment: .leading, spacing: 10) {
                    Label("idle_timer_title", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    ActivityControlView(engine: engine, settings: settings, monitor: monitor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Section: Native Keyboard Shortcuts & OSD
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("settings_section_shortcuts", systemImage: "command")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(shortcuts.isAccessibilityTrusted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(shortcuts.isAccessibilityTrusted ? "accessibility_status_active" : "accessibility_status_required")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(shortcuts.isAccessibilityTrusted ? Color.green : Color.orange)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill((shortcuts.isAccessibilityTrusted ? Color.green : Color.orange).opacity(0.12))
                        )
                    }
                    
                    Toggle("settings_capture_shortcuts", isOn: $settings.captureNativeShortcuts)
                        .toggleStyle(.checkbox)
                    
                    Toggle("settings_show_osd", isOn: $settings.showNativeOSDBezel)
                        .toggleStyle(.checkbox)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("shortcuts_desc_step")
                        Text("shortcuts_desc_fine")
                        Text("shortcuts_desc_universal")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    
                    if !shortcuts.isAccessibilityTrusted {
                        Button {
                            shortcuts.openSystemSettingsAccessibility()
                        } label: {
                            Label("shortcuts_permission_button", systemImage: "lock.shield")
                                .font(.caption)
                        }
                        .buttonStyle(.link)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
            
            // Section: Touch Bar
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("settings_section_touchbar", systemImage: "rectangle.topthird.inset.filled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if TouchBarController.isTouchBarAvailable {
                        let stage = touchBar.displayStage
                        let stageColor: Color = {
                            switch stage {
                            case .active: return .green
                            case .dimmed: return .yellow
                            case .sleeping: return .orange
                            }
                        }()
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(stageColor)
                                .frame(width: 7, height: 7)
                            Text(LocalizedStringKey(stage.rawValue))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(stageColor)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(stageColor.opacity(0.12))
                        )
                    } else {
                        Text("touchbar_not_detected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if TouchBarController.isTouchBarAvailable {
                    Toggle("settings_touchbar_controlstrip", isOn: $settings.showInTouchBarControlStrip)
                        .toggleStyle(.checkbox)
                    
                    Text("settings_touchbar_controlstrip_desc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Toggle("settings_touchbar_sync", isOn: $settings.syncBacklightWithTouchBar)
                        .toggleStyle(.checkbox)
                        .padding(.top, 4)
                    
                    Text("settings_touchbar_sync_desc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if settings.syncBacklightWithTouchBar {
                        HStack(spacing: 8) {
                            Text("settings_touchbar_dim_level")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.touchBarDimLevel, in: 0.05...0.40, step: 0.05)
                                .frame(width: 120)
                            Text("\(Int(round(settings.touchBarDimLevel * 100)))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.leading, 18)
                        .padding(.top, 2)
                    }
                    
                    Toggle("settings_sleep_clamshell_touchbar", isOn: $settings.sleepWithDisplayAndClamshell)
                        .toggleStyle(.checkbox)
                        .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings_no_touchbar_notice")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Toggle("settings_sleep_clamshell_notouchbar", isOn: $settings.sleepWithDisplayAndClamshell)
                            .toggleStyle(.checkbox)
                            .padding(.top, 2)
                        
                        Text("settings_sleep_clamshell_notouchbar_desc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 10) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(engine.isScreenSleeping ? Color.orange : Color.green)
                                    .frame(width: 7, height: 7)
                                Text(engine.isScreenSleeping ? "status_screen_off" : "status_screen_on")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(engine.isScreenSleeping ? Color.orange : Color.green)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill((engine.isScreenSleeping ? Color.orange : Color.green).opacity(0.12))
                            )
                            
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(engine.isLidClosed ? Color.orange : Color.green)
                                    .frame(width: 7, height: 7)
                                Text(engine.isLidClosed ? "status_lid_closed" : "status_lid_open")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(engine.isLidClosed ? Color.orange : Color.green)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill((engine.isLidClosed ? Color.orange : Color.green).opacity(0.12))
                            )
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Section: Power & Battery
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("settings_section_power", systemImage: "battery.100.bolt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: power.isOnBattery ? "battery.75" : "bolt.fill")
                                .font(.caption2)
                            Text(power.isOnBattery ? "\(power.batteryPercent)%" : LocalizedStringKey("power_source_ac"))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(power.isOnBattery ? Color.blue : Color.green)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill((power.isOnBattery ? Color.blue : Color.green).opacity(0.12))
                        )
                        
                        if power.isLowPowerMode {
                            HStack(spacing: 4) {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                Text("power_low_power_active")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.orange)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.orange.opacity(0.12))
                            )
                        }
                    }
                }
                
                Toggle("settings_battery_optimize", isOn: $settings.batteryOptimizationEnabled)
                    .toggleStyle(.checkbox)
                
                if settings.batteryOptimizationEnabled {
                    HStack(spacing: 8) {
                        Text("settings_battery_max_ceiling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $settings.batteryMaxBrightness) {
                            Text("25%").tag(0.25)
                            Text("50%").tag(0.50)
                            Text("75%").tag(0.75)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    .padding(.leading, 18)
                    .padding(.top, 2)
                }
                
                Toggle("settings_low_power_dim", isOn: $settings.lowPowerModeDimEnabled)
                    .toggleStyle(.checkbox)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Section: External Keyboard
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("settings_section_external_keyboard", systemImage: "keyboard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(externalKeyboard.hasExternalKeyboard ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(externalKeyboard.hasExternalKeyboard ? (externalKeyboard.externalKeyboardName.isEmpty ? LocalizedStringKey("external_keyboard_connected") : LocalizedStringKey(externalKeyboard.externalKeyboardName)) : LocalizedStringKey("external_keyboard_none"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(externalKeyboard.hasExternalKeyboard ? Color.green : Color.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((externalKeyboard.hasExternalKeyboard ? Color.green : Color.secondary).opacity(0.12))
                    )
                }
                
                Toggle("settings_disable_on_external_keyboard", isOn: $settings.disableOnExternalKeyboard)
                    .toggleStyle(.checkbox)
                
                Text("settings_disable_on_external_keyboard_desc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Section: Hardware
            VStack(alignment: .leading, spacing: 10) {
                Label("settings_section_hardware", systemImage: "laptopcomputer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("hardware_device")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(engine.hardwareModel)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("hardware_protocol")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("IOKit HID (Report ID 1, 9 bytes)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("hardware_status")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(engine.isHardwareAvailable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(engine.isHardwareAvailable ? "hardware_connected" : "hardware_not_found")
                        }
                        .fontWeight(.medium)
                    }
                    .font(.caption)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Footer
            HStack {
                Text("Lumos v1.0 • macOS")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(20)
        }
        .frame(width: 460, height: 640)
    }
}

public typealias SettingsSheetView = SettingsView


#if DEBUG
#Preview {
    SettingsView()
}
#endif
