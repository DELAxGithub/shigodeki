import SwiftUI

// MARK: - Template Header Section

struct TemplateHeaderSection: View {
    let template: ProjectTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // カテゴリアイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(template.category.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.category.icon)
                        .font(.title)
                        .foregroundColor(template.category.color)
                }
                
                // 基本情報
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // カテゴリとタグ
                    HStack {
                        Text(template.category.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(template.category.color.opacity(0.2))
                            )
                            .foregroundColor(template.category.color)
                        
                        if !template.metadata.tags.isEmpty {
                            ForEach(template.metadata.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray5))
                                    )
                                    .foregroundColor(.secondary)
                            }
                            
                            if template.metadata.tags.count > 2 {
                                Text("+\(template.metadata.tags.count - 2)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Statistics Section

struct TemplateStatisticsSection: View {
    let stats: TemplateStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("統計情報")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "フェーズ数",
                    value: "\(stats.totalPhases)",
                    icon: "list.number",
                    color: .blue
                )
                
                StatCard(
                    title: "総タスク数",
                    value: "\(stats.totalTasks)",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                StatCard(
                    title: "推定時間",
                    value: stats.estimatedCompletionHours > 0 ? "\(Int(stats.estimatedCompletionHours))h" : "未設定",
                    icon: "clock",
                    color: .orange
                )
                
                StatCard(
                    title: "平均タスク/フェーズ",
                    value: "\(String(format: "%.1f", stats.averagePhaseComplexity))",
                    icon: "chart.bar",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Phases Preview Section

struct PhasesPreviewSection: View {
    let template: ProjectTemplate
    @Binding var selectedPhaseIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("フェーズプレビュー")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !template.phases.isEmpty {
                // フェーズナビゲーション
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(template.phases.enumerated()), id: \.1.id) { index, phase in
                            PhaseNavigationButton(
                                phase: phase,
                                index: index,
                                isSelected: index == selectedPhaseIndex
                            ) {
                                selectedPhaseIndex = index
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 選択されたフェーズの詳細
                if selectedPhaseIndex < template.phases.count {
                    PhaseDetailView(phase: template.phases[selectedPhaseIndex])
                }
            } else {
                Text("このテンプレートにはフェーズが定義されていません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

// MARK: - Details Section

struct TemplateDetailsSection: View {
    let template: ProjectTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("詳細情報")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DetailRow(
                    title: "難易度",
                    value: template.metadata.difficulty.displayName,
                    icon: "gauge"
                )
                
                DetailRow(
                    title: "対象者",
                    value: template.metadata.targetAudience ?? "未設定",
                    icon: "person.2"
                )
                
                if let duration = template.metadata.estimatedDuration {
                    DetailRow(
                        title: "推定期間",
                        value: duration,
                        icon: "calendar"
                    )
                }
                
                if let skills = template.metadata.requiredSkills, !skills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "star")
                                .frame(width: 20)
                                .foregroundColor(.blue)
                            
                            Text("必要スキル")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(skills, id: \.self) { skill in
                                Text(skill)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.leading, 32)
                    }
                }
                
                if !template.metadata.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .frame(width: 20)
                                .foregroundColor(.blue)
                            
                            Text("タグ")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(template.metadata.tags, id: \.self) { tool in
                                Text(tool)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.leading, 32)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

// MARK: - Metadata Section

struct TemplateMetadataSection: View {
    let template: ProjectTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メタデータ")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                MetadataRow(title: "作成日", value: template.metadata.createdAt)
                MetadataRow(title: "バージョン", value: template.version)
                
                MetadataRow(title: "作成者", value: template.metadata.author)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Template Menu

struct TemplatePreviewMenu: View {
    let template: ProjectTemplate
    let onShare: () -> Void
    let onExport: () -> Void
    let onSelect: () -> Void
    let onCustomize: () -> Void
    
    var body: some View {
        Group {
            Button {
                onSelect()
            } label: {
                Label("このテンプレートを使用", systemImage: "checkmark.circle")
            }
            
            Button {
                onCustomize()
            } label: {
                Label("カスタマイズして使用", systemImage: "slider.horizontal.3")
            }
            
            Divider()
            
            Button {
                onShare()
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
            }
            
            Button {
                onExport()
            } label: {
                Label("エクスポート", systemImage: "arrow.up.doc")
            }
        }
    }
}