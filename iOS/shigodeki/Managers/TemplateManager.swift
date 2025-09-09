import Foundation
import SwiftUI

// MARK: - Template Manager

class TemplateManager: ObservableObject {
    @Published var allTemplates: [ProjectTemplate] = []
    @Published var builtInTemplates: [ProjectTemplate] = []
    @Published var customTemplates: [ProjectTemplate] = []
    @Published var isLoading = false
    
    func loadBuiltInTemplates() {
        // Issue #54 Fix: Prevent duplicate loading
        guard !isLoading else { return }
        
        isLoading = true
        
        // 組み込みテンプレートを読み込み（MainActorでアクセス）
        Task { @MainActor in
            let templates = BuiltInTemplates.allTemplates
            self.builtInTemplates = templates
            self.allTemplates = templates + self.customTemplates
            self.isLoading = false
            
            #if DEBUG
            print("✅ TemplateManager: Loaded \(templates.count) built-in templates")
            #endif
        }
    }
    
    func addCustomTemplate(_ template: ProjectTemplate) {
        customTemplates.append(template)
        allTemplates = builtInTemplates + customTemplates
    }
    
    func refreshTemplates() {
        loadBuiltInTemplates()
    }
}
