//
//  Environment+Entitlements.swift
//  shigodeki
//
//  Optional environment binding for EntitlementStore access.
//

import SwiftUI

private struct EntitlementStoreKey: EnvironmentKey {
    static let defaultValue: EntitlementStore? = nil
}

extension EnvironmentValues {
    var entitlementStore: EntitlementStore? {
        get { self[EntitlementStoreKey.self] }
        set { self[EntitlementStoreKey.self] = newValue }
    }
}

