//
//  TaskImprovementSuggestionView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Lightweight coordinator view
//  Components extracted to TaskImprovementStateViews.swift and TaskImprovementSuggestionComponents.swift
//

import SwiftUI

struct TaskImprovementSuggestionView: View {
    @EnvironmentObject private var sharedManagers: SharedManagerStore
    @State private var improvementEngine: TaskImprovementEngine?
    @State private var selectedSuggestions: Set<UUID> = []
    @State private var showingApplyConfirmation = false
    @State private var isEngineLoaded = false
    
    let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Analysis State Header
                AnalysisHeaderSection(engine: improvementEngine)
                
                // Content Area
                contentView
            }
            .navigationTitle("タスク改善提案")
            .navigationBarItems(
                leading: refreshButton,
                trailing: analyzeButton
            )
            .onAppear {
                initializeEngine()
            }
            .alert("改善提案を適用しますか？", isPresented: $showingApplyConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("適用") {
                    applySelectedSuggestions()
                }
            } message: {
                Text("選択された\(selectedSuggestions.count)件の改善提案を適用します。")
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if let engine = improvementEngine {
            switch engine.analysisState {
            case .idle:
                TaskImprovementIdleView(onStartAnalysis: startAnalysis)
            case .analyzing, .applying:
                TaskAnalysisProgressView(engine: engine)
            case .completed:
                SuggestionsListView(
                    engine: engine,
                    selectedSuggestions: $selectedSuggestions,
                    onApplySelected: { showingApplyConfirmation = true }
                )
            case .applied:
                TaskImprovementAppliedView(onStartNewAnalysis: startAnalysis)
            case .failed:
                TaskImprovementErrorView(engine: engine, onRetry: startAnalysis)
            }
        } else {
            TaskImprovementLoadingView()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var refreshButton: some View {
        Button("リフレッシュ") {
            initializeEngine()
        }
        .disabled(improvementEngine?.analysisState == .analyzing || improvementEngine?.analysisState == .applying)
    }
    
    private var analyzeButton: some View {
        Button("分析") {
            startAnalysis()
        }
        .disabled(improvementEngine?.analysisState == .analyzing || improvementEngine?.analysisState == .applying)
    }
    
    // MARK: - Actions
    
    private func initializeEngine() {
        Task { @MainActor in
            let aiGenerator = await sharedManagers.getAiGenerator()
            let taskManager = await sharedManagers.getTaskManager()
            let familyManager = await sharedManagers.getFamilyManager()
            
            let engine = TaskImprovementEngine(
                aiGenerator: aiGenerator,
                taskManager: taskManager,
                familyManager: familyManager
            )
            
            self.improvementEngine = engine
            self.isEngineLoaded = true
        }
    }
    
    private func startAnalysis() {
        guard let engine = improvementEngine else { return }
        
        selectedSuggestions.removeAll()
        
        Task { @MainActor in
            await engine.analyzeUserTasks(userId: userId)
        }
    }
    
    private func applySelectedSuggestions() {
        guard let engine = improvementEngine else { return }
        
        Task { @MainActor in
            do {
                try await engine.applyImprovements(selectedSuggestions)
                selectedSuggestions.removeAll()
            } catch {
                print("Error applying suggestions: \(error)")
            }
        }
    }
}
