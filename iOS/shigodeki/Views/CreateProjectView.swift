//
//  CreateProjectView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import FirebaseAuth

struct CreateProjectView: View {
    @ObservedObject var projectManager: ProjectManager
    @ObservedObject private var authManager = AuthenticationManager.shared
    @StateObject private var familyManager = FamilyManager()
    private let createProjectService = CreateProjectService()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Template integration
    @State private var selectedCreationMethod: CreationMethod = .scratch
    @State private var selectedTemplate: ProjectTemplate?
    @State private var showTemplateLibrary = false
    @State private var showFileImporter = false
    
    // AI integration
    @StateObject private var aiGenerator = AITaskGenerator()
    @State private var showAISettings = false
    @State private var aiPrompt = ""
    @State private var selectedProjectType: ProjectType?
    @State private var showProjectTypePicker = false

    // Owner selection
    @State private var selectedOwnerType: ProjectOwnerType = .individual
    @State private var selectedFamilyId: String? = nil
    
    // Feature flags
    private let aiCreationEnabled = false // Hide AI UI but keep implementation for future use
    
    enum CreationMethod {
        case scratch
        case template
        case file
        case ai
    }
    
    init(projectManager: ProjectManager, defaultOwnerType: ProjectOwnerType? = nil, defaultFamilyId: String? = nil) {
        self.projectManager = projectManager
        if let t = defaultOwnerType { self._selectedOwnerType = State(initialValue: t) }
        if let fid = defaultFamilyId { self._selectedFamilyId = State(initialValue: fid) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CreateProjectHeader()
                
                // Form
                Form {
                    OwnerSelectionSection(
                        selectedOwnerType: $selectedOwnerType,
                        selectedFamilyId: $selectedFamilyId,
                        familyManager: familyManager
                    )
                    
                    CreationMethodSelectionSection(
                        selectedCreationMethod: $selectedCreationMethod,
                        selectedTemplate: $selectedTemplate,
                        showTemplateLibrary: $showTemplateLibrary,
                        showFileImporter: $showFileImporter,
                        showAISettings: $showAISettings,
                        projectName: $projectName,
                        aiGenerator: aiGenerator
                    )
                    
                    // Template preview (if template selected)
                    if let template = selectedTemplate {
                        Section(header: Text("選択されたテンプレート")) {
                            SelectedTemplateCard(template: template) {
                                selectedTemplate = nil
                                selectedCreationMethod = .scratch
                            }
                        }
                    }
                    
                    if aiCreationEnabled && selectedCreationMethod == .ai {
                        AIPromptSection(
                            selectedProjectType: $selectedProjectType,
                            showProjectTypePicker: $showProjectTypePicker,
                            aiPrompt: $aiPrompt
                        )
                    }
                    
                    ProjectInformationSection(
                        projectName: $projectName,
                        projectDescription: $projectDescription,
                        selectedTemplate: selectedTemplate
                    )
                    
                    Section(header: Text("プロジェクト情報")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("作成者")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(authManager.currentUser?.name ?? "Unknown User")
                                    .font(.subheadline)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("作成日")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(createProjectService.formatDate(Date()))
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("プロジェクト作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createProject()
                    }
                    .disabled(isCreateButtonDisabled || isCreating)
                }
            }
            .overlay(
                CreateProjectLoadingOverlay(isShowing: isCreating)
            )
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .createProjectSheets(
                showTemplateLibrary: $showTemplateLibrary,
                showFileImporter: $showFileImporter,
                showAISettings: $showAISettings,
                showProjectTypePicker: $showProjectTypePicker,
                selectedTemplate: $selectedTemplate,
                selectedProjectType: $selectedProjectType,
                projectName: $projectName,
                selectedCreationMethod: $selectedCreationMethod,
                aiGenerator: aiGenerator
            )
        }
        .onAppear {
            // Load built-in templates when view appears
            if projectManager.templates.isEmpty {
                Task {
                    await projectManager.loadBuiltInTemplates()
                }
            }
            
            // Update available providers
            aiGenerator.updateAvailableProviders()
            // Load families for owner selection
            if let uid = authManager.currentUser?.id {
                Task { await familyManager.loadFamiliesForUser(userId: uid) }
            }
        }
        .onChange(of: authManager.currentUser?.id ?? "") { _, newId in
            guard !newId.isEmpty else { return }
            Task { await familyManager.loadFamiliesForUser(userId: newId) }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isCreateButtonDisabled: Bool {
        let validation = createProjectService.validateProjectCreation(
            name: projectName,
            selectedOwnerType: selectedOwnerType,
            selectedFamilyId: selectedFamilyId,
            selectedCreationMethod: selectedCreationMethod,
            selectedTemplate: selectedTemplate,
            aiPrompt: aiPrompt,
            selectedProjectType: selectedProjectType,
            familyManager: familyManager
        )
        return !validation.isValid || isCreating
    }
    
    private func createProject() {
        guard validateProjectInputs() else { return }
        
        guard let userId = authManager.currentUser?.id else {
            showError("ユーザー情報が見つかりません。再度サインインしてください。")
            return
        }
        
        isCreating = true
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerId = (selectedOwnerType == .individual ? userId : selectedFamilyId!)
        
        Task {
            do {
                let createdProject: Project
                
                switch selectedCreationMethod {
                case .scratch:
                    createdProject = try await projectManager.createProject(
                        name: trimmedName,
                        description: finalDescription,
                        ownerId: ownerId,
                        ownerType: selectedOwnerType,
                        createdByUserId: userId
                    )
                    
                case .template, .file:
                    guard let template = selectedTemplate else {
                        throw FirebaseError.operationFailed("テンプレートが選択されていません")
                    }
                    
                    createdProject = try await projectManager.createProjectFromTemplate(
                        template,
                        projectName: trimmedName,
                        ownerId: ownerId,
                        ownerType: selectedOwnerType,
                        createdByUserId: userId,
                        customizations: nil
                    )
                
                case .ai:
                    createdProject = try await projectManager.createProject(
                        name: trimmedName,
                        description: finalDescription,
                        ownerId: ownerId,
                        ownerType: selectedOwnerType,
                        createdByUserId: userId
                    )
                    
                    await aiGenerator.generateTaskSuggestions(
                        for: aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                        projectType: selectedProjectType
                    )
                    
                    if let suggestions = aiGenerator.generatedSuggestions {
                        let aiTasks = aiGenerator.convertSuggestionsToTasks(suggestions, for: createdProject)
                        await createProjectService.createInitialTasksFromAI(aiTasks, for: createdProject)
                    }
                }
                
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateProjectInputs() -> Bool {
        let validation = createProjectService.validateProjectCreation(
            name: projectName,
            selectedOwnerType: selectedOwnerType,
            selectedFamilyId: selectedFamilyId,
            selectedCreationMethod: selectedCreationMethod,
            selectedTemplate: selectedTemplate,
            aiPrompt: aiPrompt,
            selectedProjectType: selectedProjectType,
            familyManager: familyManager
        )
        
        if !validation.isValid {
            showError(validation.reason ?? "入力内容を確認してください")
            return false
        }
        return true
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}


#Preview {
    CreateProjectView(projectManager: ProjectManager())
}
