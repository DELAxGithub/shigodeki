//
//  ContentView.swift
//  shigodeki
//
//  Created by Hiroshi Kodera on 2025-08-27.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = SimpleAuthenticationManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    ContentView()
}
