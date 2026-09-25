//
//  LumosCLIHandler.swift
//  Lumos
//
//  Created by Felix Almeida on 25/09/26.
//

import Foundation
import AppKit

public enum LumosCLICommand: Equatable {
    case get
    case set(Double)
    case toggle
    case status
    case help
    case notCLI
}

@MainActor
public final class LumosCLIHandler {
    public static let shared = LumosCLIHandler()
    
    public static let notificationName = NSNotification.Name("dev.felix01sa.Lumos.CLICommand")
    
    public static func parseCommand() -> LumosCLICommand {
        let args = CommandLine.arguments
        guard args.count > 1 else { return .notCLI }
        
        let sub = args[1].lowercased()
        
        // Ignore macOS system arguments when launched from Finder/Dock
        if sub.starts(with: "-psn") || sub.starts(with: "-applepersistence") || sub.starts(with: "-ns") {
            return .notCLI
        }
        
        switch sub {
        case "get":
            return .get
        case "set":
            guard args.count > 2, let level = parseBrightness(args[2]) else {
                print("Error: Missing or invalid brightness value. Example: lumos set 50%")
                exit(1)
            }
            return .set(level)
        case "toggle":
            return .toggle
        case "status":
            return .status
        case "help", "--help", "-h":
            return .help
        default:
            // Check if user passed a bare percentage directly, e.g. "lumos 50%"
            if let level = parseBrightness(sub) {
                return .set(level)
            }
            return .help
        }
    }
    
    public static func parseBrightness(_ arg: String) -> Double? {
        let trimmed = arg.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
        guard let val = Double(trimmed) else { return nil }
        if val <= 1.0 && !arg.contains("%") {
            return min(max(val, 0.0), 1.0)
        } else if val <= 100.0 {
            return min(max(val / 100.0, 0.0), 1.0)
        } else if val <= 512.0 {
            return min(max(val / 512.0, 0.0), 1.0)
        }
        return nil
    }
    
    public static func handleCLIIfRequested() {
        let cmd = parseCommand()
        guard cmd != .notCLI else { return }
        
        switch cmd {
        case .get:
            let current = LumosSettings.shared.lastActiveBrightness
            let pct = Int(round(current * 100))
            print("\(pct)%")
            exit(0)
            
        case .set(let level):
            postDistributedCommand(action: "set", value: level)
            KeyboardBacklightEngine.shared.setBrightness(level)
            let pct = Int(round(level * 100))
            print("Lumos: Keyboard backlight set to \(pct)%")
            exit(0)
            
        case .toggle:
            postDistributedCommand(action: "toggle", value: 0.0)
            KeyboardBacklightEngine.shared.togglePower()
            let state = KeyboardBacklightEngine.shared.isOn ? "ON" : "OFF"
            print("Lumos: Keyboard backlight toggled \(state)")
            exit(0)
            
        case .status:
            let engine = KeyboardBacklightEngine.shared
            let power = PowerManagementController.shared
            let ext = ExternalKeyboardMonitor.shared
            
            let statusDict: [String: Any] = [
                "brightness": engine.brightness,
                "percentage": "\(Int(round(engine.brightness * 100)))%",
                "rawBrightness": engine.rawBrightness,
                "isOn": engine.isOn,
                "powerSource": power.isOnBattery ? "Battery" : "AC",
                "batteryPercent": power.batteryPercent,
                "isLowPowerMode": power.isLowPowerMode,
                "hasExternalKeyboard": ext.hasExternalKeyboard,
                "externalKeyboard": ext.externalKeyboardName
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: statusDict, options: [.prettyPrinted, .sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                print(json)
            } else {
                print("Lumos: \(Int(round(engine.brightness * 100)))% (\(engine.isOn ? "ON" : "OFF"))")
            }
            exit(0)
            
        case .help:
            print("""
            Lumos CLI — MacBook Keyboard Backlight Controller

            USAGE:
              lumos <command> [value]

            COMMANDS:
              get               Print current keyboard backlight brightness (e.g. 75%)
              set <value>       Set brightness level (e.g. lumos set 50% or lumos set 0.5)
              toggle            Toggle keyboard backlight on or off
              status            Output system and backlight status in JSON format
              help              Show this help message

            EXAMPLES:
              lumos get
              lumos set 25%
              lumos set 100%
              lumos toggle
              lumos status
            """)
            exit(0)
            
        case .notCLI:
            break
        }
    }
    
    private static func postDistributedCommand(action: String, value: Double) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: ["action": action, "value": value],
            deliverImmediately: true
        )
    }
    
    public func startListening() {
        DistributedNotificationCenter.default().addObserver(
            forName: LumosCLIHandler.notificationName,
            object: nil,
            queue: .main
        ) { notif in
            guard let userInfo = notif.userInfo,
                  let action = userInfo["action"] as? String else { return }
            
            Task { @MainActor in
                if action == "set", let val = userInfo["value"] as? Double {
                    KeyboardBacklightEngine.shared.setBrightness(val)
                } else if action == "toggle" {
                    KeyboardBacklightEngine.shared.togglePower()
                }
            }
        }
    }
}
