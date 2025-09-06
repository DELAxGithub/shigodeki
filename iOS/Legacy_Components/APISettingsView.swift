import SwiftUI

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = APISettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Services")) {
                    ForEach(KeychainManager.APIProvider.allCases, id: \.self) { provider in
                        APIProviderRow(
                            provider: provider,
                            isConfigured: viewModel.configuredProviders.contains(provider),
                            onConfigure: { viewModel.showConfiguration(for: provider) }
                        )
                    }
                }
                
                Section(header: Text("About"), footer: footerText) {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.green)
                        Text("API keys are stored securely in Keychain")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
        Text("API keys are required to generate intelligent task suggestions using AI services.")
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
        isConfigured ? "Configured" : "Not configured"
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
                Section(header: Text("\(provider.displayName) API Key")) {
                    SecureField("Enter your API key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text(instructionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Security Notice")) {
                    Label("Your API key will be stored securely in Keychain", systemImage: "lock.shield")
                        .font(.caption)
                    Label("Keys are never transmitted except to the respective AI service", systemImage: "network.badge.shield.half.filled")
                        .font(.caption)
                }
            }
            .navigationTitle("Configure \(provider.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .alert("Configuration", isPresented: $showingAlert) {
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
            return "Get your API key from platform.openai.com → API Keys"
        case .claude:
            return "Get your API key from console.anthropic.com → API Keys"
        }
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate format
        guard KeychainManager.shared.validateAPIKey(trimmedKey, for: provider) else {
            alertMessage = "Invalid API key format for \(provider.displayName)"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        do {
            try KeychainManager.shared.storeAPIKey(trimmedKey, for: provider)
            alertMessage = "\(provider.displayName) API key saved successfully"
            showingAlert = true
        } catch {
            alertMessage = "Error saving API key: \(error.localizedDescription)"
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