//
//  RemoteConfigGate.swift
//  shigodeki
//
//  Minimal remote-config bridge used for feature kill switches.
//

import Foundation

final class RemoteConfigGate {
    static let shared = RemoteConfigGate()
    private init() {}

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if let override = UserDefaults.standard.object(forKey: key) as? Bool {
            return override
        }
        // TODO: integrate Firebase Remote Config
        return defaultValue
    }
}

