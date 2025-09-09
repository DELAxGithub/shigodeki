import SwiftUI

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = APISettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AIサービス")) {
                    ForEach(KeychainManager.APIProvider.allCases, id: \.self) { provider in
                        APIProviderRow(
                            provider: provider,
                            isConfigured: viewModel.configuredProviders.contains(provider),
                            onConfigure: { viewModel.showConfiguration(for: provider) }
                        )
                    }
                }
                
                Section(header: Text("情報"), footer: footerText) {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.green)
                        Text("APIキーはキーチェーンに安全に保存されます")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("AI設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadConfiguredProviders()
            }
            .sheet(item: $viewModel.configurationProvider) { provider in
                APIKeyConfigurationView(provider: provider) { success in
                    if success {
                        viewModel.loadConfiguredProviders()
                    }
                }
            }
        }
    }
    
    private var footerText: Text {
        Text("AIサービスを使用してスマートなタスク提案を生成するためにAPIキーが必要です。")
    }
}

struct APIProviderRow: View {
    let provider: KeychainManager.APIProvider
    let isConfigured: Bool
    let onConfigure: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.headline)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(isConfigured ? .green : .secondary)
            }
            
            Spacer()
            
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "gear")
                .foregroundColor(isConfigured ? .green : .blue)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onConfigure()
        }
    }
    
    private var statusText: String {
        isConfigured ? "設定済み" : "未設定"
    }
}

struct APIKeyConfigurationView: View {
    let provider: KeychainManager.APIProvider
    let onComplete: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("\(provider.displayName) APIキー")) {
                    SecureField("APIキーを入力", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text(instructionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("セキュリティの注意")) {
                    Label("APIキーはキーチェーンに安全に保存されます", systemImage: "lock.shield")
                        .font(.caption)
                    Label("キーは対応するAIサービス以外には絶対に送信されません", systemImage: "network.badge.shield.half.filled")
                        .font(.caption)
                }
            }
            .navigationTitle("\(provider.displayName)の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .alert("設定", isPresented: $showingAlert) {
                Button("OK") {
                    if !alertMessage.contains("Error") {
                        onComplete(true)
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var instructionText: String {
        switch provider {
        case .openAI:
            return "platform.openai.com → API KeysでAPIキーを取得してください"
        case .claude:
            return "console.anthropic.com → API KeysでAPIキーを取得してください"
        case .gemini:
            return "aistudio.google.com → Get API KeyでAPIキーを取得してください"
        }
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate format
        guard KeychainManager.shared.validateAPIKey(trimmedKey, for: provider) else {
            alertMessage = "\(provider.displayName)のAPIキーの形式が無効です"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        do {
            try KeychainManager.shared.storeAPIKey(trimmedKey, for: provider)
            alertMessage = "\(provider.displayName)のAPIキーを保存しました"
            showingAlert = true
        } catch {
            alertMessage = "APIキーの保存エラー: \(error.localizedDescription)"
            showingAlert = true
        }
        
        isLoading = false
    }
}

@MainActor
class APISettingsViewModel: ObservableObject {
    @Published var configuredProviders: [KeychainManager.APIProvider] = []
    @Published var configurationProvider: KeychainManager.APIProvider?
    
    func loadConfiguredProviders() {
        configuredProviders = KeychainManager.shared.getConfiguredProviders()
    }
    
    func showConfiguration(for provider: KeychainManager.APIProvider) {
        configurationProvider = provider
    }
}

// Make APIProvider conform to Identifiable for sheet presentation
extension KeychainManager.APIProvider: Identifiable {
    public var id: String { rawValue }
}

#Preview {
    APISettingsView()
}