//
//  CreateProjectView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

struct CreateProjectView: View {
    @ObservedObject var projectManager: ProjectManager
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var familyManager = FamilyManager()
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
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("新しいプロジェクト")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("プロジェクトを作成してタスクを整理しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Form
                Form {
                    // Owner selection
                    Section(header: Text("所有者")) {
                        Picker("所有者タイプ", selection: $selectedOwnerType) {
                            Text(ProjectOwnerType.individual.displayName).tag(ProjectOwnerType.individual)
                            Text(ProjectOwnerType.family.displayName).tag(ProjectOwnerType.family)
                        }
                        .pickerStyle(.segmented)

                        if selectedOwnerType == .family {
                            if familyManager.families.isEmpty {
                                Text("家族グループがありません。家族タブから作成/参加してください。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("家族グループ", selection: $selectedFamilyId) {
                                    Text("選択してください").tag(String?.none)
                                    ForEach(familyManager.families) { fam in
                                        Text(fam.name).tag(Optional(fam.id))
                                    }
                                }
                            }
                        }
                    }
                    // Creation method selection
                    Section(header: Text("作成方法")) {
                        VStack(spacing: 12) {
                            CreationMethodCard(
                                title: "新規作成",
                                subtitle: "最初から作成",
                                icon: "doc.badge.plus",
                                isSelected: selectedCreationMethod == .scratch
                            ) {
                                selectedCreationMethod = .scratch
                                selectedTemplate = nil
                                if projectName.isEmpty {
                                    projectName = ""
                                }
                            }
                            
                            CreationMethodCard(
                                title: "テンプレートから作成",
                                subtitle: "事前定義されたテンプレートを使用",
                                icon: "doc.on.doc",
                                isSelected: selectedCreationMethod == .template
                            ) {
                                selectedCreationMethod = .template
                                showTemplateLibrary = true
                            }
                            
                            CreationMethodCard(
                                title: "ファイルからインポート",
                                subtitle: "JSON/Templateファイルを読み込み",
                                icon: "square.and.arrow.down",
                                isSelected: selectedCreationMethod == .file
                            ) {
                                selectedCreationMethod = .file
                                showFileImporter = true
                            }
                            
                            CreationMethodCard(
                                title: "AI生成",
                                subtitle: "AI を使用してタスクを自動生成",
                                icon: "brain",
                                isSelected: selectedCreationMethod == .ai
                            ) {
                                if aiGenerator.availableProviders.isEmpty {
                                    showAISettings = true
                                } else {
                                    selectedCreationMethod = .ai
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    
                    // Template preview (if template selected)
                    if let template = selectedTemplate {
                        Section(header: Text("選択されたテンプレート")) {
                            SelectedTemplateCard(template: template) {
                                selectedTemplate = nil
                                selectedCreationMethod = .scratch
                            }
                        }
                    }
                    
                    // AI prompt section (if AI selected)
                    if selectedCreationMethod == .ai {
                        Section(header: Text("AI プロジェクト生成")) {
                            // Project type picker
                            Button {
                                showProjectTypePicker = true
                            } label: {
                                HStack {
                                    Text("プロジェクトタイプ")
                                    Spacer()
                                    if let projectType = selectedProjectType {
                                        HStack {
                                            Image(systemName: projectType.icon)
                                                .foregroundColor(projectType.color)
                                            Text(projectType.displayName)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("選択してください")
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            
                            // AI prompt input
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("プロジェクトの説明")
                                        .font(.subheadline)
                                    Spacer()
                                    if !aiGenerator.availableProviders.isEmpty {
                                        Button {
                                            showAISettings = true
                                        } label: {
                                            Image(systemName: "gear")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                ZStack(alignment: .topLeading) {
                                    if aiPrompt.isEmpty {
                                        VStack {
                                            HStack {
                                                Text("何を作りたいか詳しく説明してください...")
                                                    .foregroundColor(Color(.placeholderText))
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                    }
                                    
                                    TextEditor(text: $aiPrompt)
                                        .frame(minHeight: 100)
                                }
                            }
                            
                            // AI status
                            if aiGenerator.isGenerating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(aiGenerator.progressMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let error = aiGenerator.error {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(error.localizedDescription)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if aiGenerator.availableProviders.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("AI機能を使用するにはAPIキーの設定が必要です")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Button {
                                        showAISettings = true
                                    } label: {
                                        Text("API設定を開く")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Section(header: Text("基本情報")) {
                        TextField("プロジェクト名", text: $projectName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(false)
                        
                        ZStack(alignment: .topLeading) {
                            if projectDescription.isEmpty {
                                VStack {
                                    HStack {
                                        Text("プロジェクトの説明（オプション）")
                                            .foregroundColor(Color(.placeholderText))
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .padding(.leading, 4)
                            }
                            
                            TextEditor(text: $projectDescription)
                                .frame(minHeight: 80)
                        }
                    }
                    
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
                                Text(formatDate(Date()))
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
                Group {
                    if isCreating {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("プロジェクトを作成中...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            )
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showTemplateLibrary) {
                TemplateLibraryView(
                    isPresented: $showTemplateLibrary,
                    selectedTemplate: $selectedTemplate
                )
                .onDisappear {
                    if selectedTemplate != nil {
                        selectedCreationMethod = .template
                        // Pre-fill project name from template
                        if projectName.isEmpty, let template = selectedTemplate {
                            projectName = template.name
                        }
                    }
                }
            }
            .sheet(isPresented: $showFileImporter) {
                TemplateFilePickerView(
                    isPresented: $showFileImporter,
                    selectedTemplate: $selectedTemplate
                )
                .onDisappear {
                    if selectedTemplate != nil {
                        selectedCreationMethod = .file
                        // Pre-fill project name from template
                        if projectName.isEmpty, let template = selectedTemplate {
                            projectName = template.name
                        }
                    }
                }
            }
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
        }
        .sheet(isPresented: $showAISettings) {
            APISettingsView()
                .onDisappear {
                    aiGenerator.updateAvailableProviders()
                }
        }
        .sheet(isPresented: $showProjectTypePicker) {
            ProjectTypePickerView(selectedType: $selectedProjectType)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isCreateButtonDisabled: Bool {
        let nameEmpty = projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        switch selectedCreationMethod {
        case .ai:
            let promptEmpty = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return nameEmpty || promptEmpty
        default:
            return nameEmpty
        }
    }
    
    private func createProject() {
        print("🎯 Create project button tapped")
        print("📝 Creation method: \(selectedCreationMethod)")
        print("📝 Input - Name: '\(projectName)', Description: '\(projectDescription)'")
        
        guard let userId = authManager.currentUser?.id else {
            print("❌ No user ID found")
            errorMessage = "ユーザー情報が見つかりません"
            showingError = true
            return
        }
        
        print("👤 Current user ID: '\(userId)'")
        
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("❌ Project name is empty")
            errorMessage = "プロジェクト名を入力してください"
            showingError = true
            return
        }
        
        print("✅ Validation passed - proceeding with creation")
        isCreating = true
        
        Task {
            do {
                let description = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalDescription = description.isEmpty ? nil : description
                print("📋 Final inputs - Name: '\(trimmedName)', Description: '\(finalDescription ?? "nil")', Owner: '\(userId)'")
                
                let createdProject: Project
                
                switch selectedCreationMethod {
                case .scratch:
                    print("🔨 Creating project from scratch")
                    createdProject = try await projectManager.createProject(
                        name: trimmedName,
                        description: finalDescription,
                        ownerId: (selectedOwnerType == .individual ? userId : (selectedFamilyId ?? userId)),
                        ownerType: selectedOwnerType,
                        createdByUserId: userId
                    )
                    
                case .template, .file:
                    print("🔍 Debug - selectedCreationMethod: \(selectedCreationMethod), selectedTemplate: \(selectedTemplate?.name ?? "nil")")
                    guard let template = selectedTemplate else {
                        print("❌ No template selected")
                        print("🔍 Current selectedCreationMethod: \(selectedCreationMethod)")
                        print("🔍 selectedTemplate is nil")
                        throw FirebaseError.operationFailed("テンプレートが選択されていません")
                    }
                    
                    print("📋 Creating project from template: '\(template.name)'")
                    createdProject = try await projectManager.createProjectFromTemplate(
                        template,
                        projectName: trimmedName,
                        ownerId: (selectedOwnerType == .individual ? userId : (selectedFamilyId ?? userId)),
                        ownerType: selectedOwnerType,
                        createdByUserId: userId,
                        customizations: nil // Basic implementation - can be enhanced later
                    )
                
                case .ai:
                    print("🤖 Creating project with AI generation")
                    let trimmedPrompt = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedPrompt.isEmpty else {
                        throw FirebaseError.operationFailed("AIプロンプトを入力してください")
                    }
                    
                    print("🔨 Creating base project first")
                    createdProject = try await projectManager.createProject(
                        name: trimmedName,
                        description: finalDescription,
                        ownerId: (selectedOwnerType == .individual ? userId : (selectedFamilyId ?? userId)),
                        ownerType: selectedOwnerType,
                        createdByUserId: userId
                    )
                    
                    print("🤖 Generating AI task suggestions")
                    await aiGenerator.generateTaskSuggestions(
                        for: trimmedPrompt,
                        projectType: selectedProjectType
                    )
                    
                    if let suggestions = aiGenerator.generatedSuggestions {
                        print("✨ AI generated \(suggestions.tasks.count) task suggestions")
                        let aiTasks = aiGenerator.convertSuggestionsToTasks(suggestions, for: createdProject)
                        
                        // Note: Task creation would need proper implementation
                        // with proper list and phase management
                        print("✨ Generated \(aiTasks.count) tasks for future implementation")
                        // TODO: Implement proper task creation with list/phase setup
                    } else if let error = aiGenerator.error {
                        print("⚠️ AI generation failed: \(error.localizedDescription)")
                        // Continue with basic project - don't fail the entire creation
                    }
                }
                
                print("🎉 Project creation successful in view! Project ID: \(createdProject.id ?? "NO_ID")")
                
                await MainActor.run {
                    print("📱 Dismissing create project view")
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("❌ Project creation failed in view: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    print("📱 Showing error to user: \(errorMessage)")
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct CreationMethodCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primaryBlue.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundColor(isSelected ? .primaryBlue : .secondary)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primaryBlue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primaryBlue.opacity(0.05) : Color(.systemGray6))
                    .stroke(isSelected ? Color.primaryBlue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedTemplateCard: View {
    let template: ProjectTemplate
    let onRemove: () -> Void
    
    private var stats: TemplateStats {
        TemplateStats(template: template)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: template.category.icon)
                        .foregroundColor(template.category.color)
                        .font(.subheadline)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                StatItem(
                    icon: "list.bullet",
                    value: "\(stats.totalPhases)",
                    label: "フェーズ"
                )
                
                StatItem(
                    icon: "checkmark.square",
                    value: "\(stats.totalTasks)",
                    label: "タスク"
                )
                
                StatItem(
                    icon: "clock",
                    value: stats.completionTimeRange,
                    label: "期間"
                )
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
}

#Preview {
    CreateProjectView(projectManager: ProjectManager())
}
