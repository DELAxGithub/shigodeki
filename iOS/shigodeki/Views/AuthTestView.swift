//
//  AuthTestView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct AuthTestView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showTestResults = false
    @State private var testResults: [TestResult] = []
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1)
                            .id("top")
                        
                        AuthStatusCard(authManager: authManager)
                        
                        TestControlsCard(authManager: authManager) { results in
                            testResults = results
                            showTestResults = true
                        }
                        
                        DebugInfoCard(authManager: authManager)
                        
                        DataManagementCard(authManager: authManager)
                    }
                    .padding()
                }
                .navigationTitle("認証テスト")
                .navigationBarTitleDisplayMode(.large)
                #if DEBUG
                .onReceive(NotificationCenter.default.publisher(for: .testTabSelected)) { _ in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showTestResults) {
            TestResultsView(results: testResults)
        }
    }
}


#Preview {
    AuthTestView()
}
