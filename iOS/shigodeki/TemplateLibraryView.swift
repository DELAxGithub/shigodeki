//
//  TemplateLibraryView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct TemplateLibraryView: View {
    @StateObject private var templateManager = TemplateManager()
    
    @Binding var isPresented: Bool
    @Binding var selectedTemplate: ProjectTemplate?
    
    @State private var selectedCategory: TemplateCategory? = nil
    @State private var searchText = ""
    @State private var showFilePicker = false
    @State private var showTemplatePreview = false
    @State private var previewTemplate: ProjectTemplate?
    @State private var sortOption: SortOption = .name
    
    enum SortOption: String, CaseIterable {
        case name = "名前"
        case category = "カテゴリ"
        case difficulty = "難易度"
        case recent = "最新"
        
        var systemImage: String {
            switch self {
            case .name: return "textformat.abc"
            case .category: return "folder"
            case .difficulty: return "star"
            case .recent: return "clock"
            }
        }
    }
    
    var filteredTemplates: [ProjectTemplate] {
        var templates = templateManager.allTemplates
        
        // カテゴリフィルタ
        if let selectedCategory = selectedCategory {
            templates = templates.filter { $0.category == selectedCategory }
        }
        
        // 検索フィルタ
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description?.localizedCaseInsensitiveContains(searchText) == true ||
                template.metadata.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // ソート
        switch sortOption {
        case .name:
            templates.sort { $0.name < $1.name }
        case .category:
            templates.sort { $0.category.displayName < $1.category.displayName }
        case .difficulty:
            templates.sort { $0.metadata.difficulty.stars < $1.metadata.difficulty.stars }
        case .recent:
            templates.sort { 
                let date1 = ISO8601DateFormatter().date(from: $0.metadata.createdAt) ?? Date.distantPast
                let date2 = ISO8601DateFormatter().date(from: $1.metadata.createdAt) ?? Date.distantPast
                return date1 > date2
            }
        }
        
        return templates
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索・フィルタセクション
                searchAndFilterSection
                
                // カテゴリフィルタ
                if selectedCategory == nil {
                    categoryFilterSection
                }
                
                // テンプレート一覧
                templateListSection
            }
            .navigationTitle("テンプレートライブラリ")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: Menu {
                    menuContent
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
        }
        .sheet(isPresented: $showFilePicker) {
            TemplateFilePickerView(
                isPresented: $showFilePicker,
                selectedTemplate: $selectedTemplate
            )
        }
        .sheet(isPresented: $showTemplatePreview) {
            if let template = previewTemplate {
                TemplatePreviewView(
                    template: template,
                    isPresented: $showTemplatePreview,
                    onSelect: { selectedTemplate in
                        self.selectedTemplate = selectedTemplate
                        isPresented = false
                    }
                )
            }
        }
        .task {
            // Issue #54 Fix: Ensure templates load before view displays
            if templateManager.allTemplates.isEmpty {
                templateManager.loadBuiltInTemplates()
            }
        }
        .onAppear {
            // Fallback for cases where .task doesn't trigger
            if templateManager.allTemplates.isEmpty && !templateManager.isLoading {
                templateManager.loadBuiltInTemplates()
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 検索バー
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("テンプレートを検索...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // ソートメニュー
                Menu {
                    ForEach(SortOption.allCases, id: \.rawValue) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.systemImage)
                                Text(option.rawValue)
                                if sortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.primaryBlue)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            // アクティブフィルタ表示
            if selectedCategory != nil || !searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let category = selectedCategory {
                            FilterChip(
                                title: category.displayName,
                                icon: category.icon,
                                color: category.color
                            ) {
                                selectedCategory = nil
                            }
                        }
                        
                        if !searchText.isEmpty {
                            FilterChip(
                                title: "「\(searchText)」",
                                icon: "magnifyingglass",
                                color: .primaryBlue
                            ) {
                                searchText = ""
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(TemplateCategory.allCases, id: \.rawValue) { category in
                    let count = templateManager.allTemplates.filter { $0.category == category }.count
                    
                    if count > 0 {
                        CategoryCard(
                            category: category,
                            count: count,
                            isSelected: false
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var templateListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredTemplates.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredTemplates, id: \.id) { template in
                        TemplateCard(template: template) {
                            previewTemplate = template
                            showTemplatePreview = true
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("テンプレートが見つかりません")
                    .font(.headline)
                
                if selectedCategory != nil || !searchText.isEmpty {
                    Text("フィルタ条件を変更してお試しください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("カスタムテンプレートをインポートできます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("ファイルをインポート") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var menuContent: some View {
        Group {
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("ファイルをインポート")
                }
            }
            
            Divider()
            
            Button {
                selectedCategory = nil
                searchText = ""
            } label: {
                HStack {
                    Image(systemName: "clear")
                    Text("フィルタをクリア")
                }
            }
            .disabled(selectedCategory == nil && searchText.isEmpty)
            
            Button {
                templateManager.refreshTemplates()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("更新")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CategoryCard: View {
    let category: TemplateCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(category.color)
                }
                
                VStack(spacing: 2) {
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color.opacity(0.1) : Color.clear)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateCard: View {
    let template: ProjectTemplate
    let action: () -> Void
    
    private var stats: TemplateStats {
        TemplateStats(template: template)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // ヘッダー
                HStack(alignment: .top, spacing: 12) {
                    // カテゴリアイコン
                    ZStack {
                        Circle()
                            .fill(template.category.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: template.category.icon)
                            .foregroundColor(template.category.color)
                            .font(.title3)
                    }
                    
                    // メイン情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if let description = template.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // メタデータ
                        HStack(spacing: 8) {
                            DifficultyBadge(difficulty: template.metadata.difficulty)
                            
                            Text(template.category.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(template.category.color.opacity(0.2))
                                .foregroundColor(template.category.color)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                }
                
                // 統計情報
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
                
                // タグ
                if !template.metadata.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(template.metadata.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(4)
                            }
                            
                            if template.metadata.tags.count > 3 {
                                Text("+\(template.metadata.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: TemplateDifficulty
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                Image(systemName: index < difficulty.stars ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(difficulty.color)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            
            Text(title)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

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
        
        // 組み込みテンプレートを非同期で読み込み
        DispatchQueue.global(qos: .userInitiated).async {
            let templates = BuiltInTemplates.allTemplates
            
            DispatchQueue.main.async {
                self.builtInTemplates = templates
                self.allTemplates = templates + self.customTemplates
                self.isLoading = false
                
                #if DEBUG
                print("✅ TemplateManager: Loaded \(templates.count) built-in templates")
                #endif
            }
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

// MARK: - Preview

struct TemplateLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateLibraryView(
            isPresented: .constant(true),
            selectedTemplate: .constant(nil)
        )
    }
}