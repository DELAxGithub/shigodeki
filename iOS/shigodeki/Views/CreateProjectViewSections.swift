import SwiftUI
import FirebaseAuth

// Feature flags
private let aiCreationEnabled = false // Hide AI creation UI while keeping code for future use

// MARK: - Owner Selection Section

struct OwnerSelectionSection: View {
    @Binding var selectedOwnerType: ProjectOwnerType
    @Binding var selectedFamilyId: String?
    @ObservedObject var familyManager: FamilyManager
    
    var body: some View {
        Section(header: Text("所有者")) {
            Picker("所有者タイプ", selection: $selectedOwnerType) {
                Text(ProjectOwnerType.individual.displayName).tag(ProjectOwnerType.individual)
                Text(ProjectOwnerType.family.displayName).tag(ProjectOwnerType.family)
            }
            .pickerStyle(.segmented)

            if selectedOwnerType == .family {
                if familyManager.isLoading {
                    HStack { 
                        ProgressView().scaleEffect(0.8) 
                        Text("家族を読み込み中...").font(.caption).foregroundColor(.secondary) 
                    }
                } else if familyManager.families.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("家族グループがまだ作成されていません")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        Text("家族プロジェクトを作成するには、先に家族グループを作成または加入する必要があります。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("💡 個人プロジェクトとして作成する場合は「個人」を選択してください。")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Picker("家族グループ", selection: $selectedFamilyId) {
                        Text("選択してください").tag(String?.none)
                        ForEach(familyManager.families) { fam in
                            Text(fam.name).tag(Optional(fam.id))
                        }
                    }
                    
                    if selectedFamilyId == nil {
                        Text("⚠️ 家族グループを選択してください")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Creation Method Section

struct CreationMethodSelectionSection: View {
    @Binding var selectedCreationMethod: CreateProjectView.CreationMethod
    @Binding var selectedTemplate: ProjectTemplate?
    @Binding var showTemplateLibrary: Bool
    @Binding var showFileImporter: Bool
    @Binding var showAISettings: Bool
    @Binding var projectName: String
    @ObservedObject var aiGenerator: AITaskGenerator
    
    var body: some View {
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
                
                if aiCreationEnabled {
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
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - AI Prompt Section

struct AIPromptSection: View {
    @Binding var selectedProjectType: ProjectType?
    @Binding var showProjectTypePicker: Bool
    @Binding var aiPrompt: String
    
    var body: some View {
        Section(header: Text("AI プロジェクト生成")) {
            // Project type picker
            Button {
                showProjectTypePicker = true
            } label: {
                HStack {
                    Text("プロジェクトタイプ")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack {
                        if let type = selectedProjectType {
                            Text(type.rawValue)
                                .foregroundColor(.secondary)
                        } else {
                            Text("選択してください")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(.blue)
                    Text("プロジェクト内容")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ZStack(alignment: .topLeading) {
                    if aiPrompt.isEmpty {
                        VStack {
                            HStack {
                                Text("例: 「家族での旅行計画」「新商品の開発」「引っ越し準備」")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    
                    TextEditor(text: $aiPrompt)
                        .frame(minHeight: 80)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("詳しく説明するほど、より適切なプロジェクトプランが生成されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Project Information Section

struct ProjectInformationSection: View {
    @Binding var projectName: String
    @Binding var projectDescription: String
    let selectedTemplate: ProjectTemplate?
    
    var body: some View {
        Section(header: Text("プロジェクト情報")) {
            TextField("プロジェクト名", text: $projectName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text("プロジェクト説明（任意）")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ZStack(alignment: .topLeading) {
                    if projectDescription.isEmpty {
                        VStack {
                            HStack {
                                Text("このプロジェクトの目的や概要を入力してください")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    
                    TextEditor(text: $projectDescription)
                        .frame(minHeight: 80)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            if let template = selectedTemplate {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("テンプレートから自動入力")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text("選択したテンプレート「\(template.name)」の情報がプロジェクト作成時に自動的に適用されます。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
