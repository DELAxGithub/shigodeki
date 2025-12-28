//
//  FeatureFlagOverrides.swift
//  shigodeki
//
//  Optional helper to inspect UserDefaults-based flag overrides for debugging.
//

import Foundation

enum FeatureFlagOverrides {
    static func applyLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.isEmpty == false else { return }

        let defaults = UserDefaults.standard
        for (index, argument) in arguments.enumerated() {
            guard argument.hasPrefix("-FF.") || argument.hasPrefix("-ff.") else { continue }

            let keyValuePortion = argument.dropFirst(4)
            if let equalIndex = keyValuePortion.firstIndex(of: "=") {
                let key = String(keyValuePortion[..<equalIndex])
                let value = String(keyValuePortion[keyValuePortion.index(after: equalIndex)...])
                if let boolValue = normalizedBool(from: value) {
                    defaults.set(boolValue, forKey: key)
                    logOverrideApplied(key: key, value: boolValue, source: "inline")
                }
            } else if index + 1 < arguments.count {
                let valueCandidate = arguments[index + 1]
                if valueCandidate.hasPrefix("-") == false,
                   let boolValue = normalizedBool(from: valueCandidate) {
                    let key = String(keyValuePortion)
                    defaults.set(boolValue, forKey: key)
                    logOverrideApplied(key: key, value: boolValue, source: "paired")
                }
            }
        }
    }

    static func readBool(for key: String) -> Bool? {
        UserDefaults.standard.object(forKey: key) as? Bool
    }

    private static func normalizedBool(from string: String) -> Bool? {
        switch string.lowercased() {
        case "1", "true", "yes", "y": return true
        case "0", "false", "no", "n": return false
        default: return nil
        }
    }

    private static func logOverrideApplied(key: String, value: Bool, source: String) {
        #if DEBUG
        print("[Flags] Override applied (\(source)) - \(key)=\(value)")
        #endif
    }
}
