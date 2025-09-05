//
//  TemplatePreviewView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct TemplatePreviewView: View {
    let template: ProjectTemplate
    @Binding var isPresented: Bool
    let onSelect: (ProjectTemplate) -> Void
    
    @State private var selectedPhaseIndex = 0
    @State private var showCustomizationSheet = false
    @State private var customizations = ProjectCustomizations()
    @State private var projectName = ""
    
    private var stats: TemplateStats {
        TemplateStats(template: template)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TemplateHeaderSection(template: template)
                    TemplateStatisticsSection(stats: stats)
                    PhasesPreviewSection(template: template, selectedPhaseIndex: $selectedPhaseIndex)
                    TemplateDetailsSection(template: template)
                    TemplateMetadataSection(template: template)
                }
                .padding()
            }
            .navigationTitle("テンプレートプレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: Menu {
                    TemplatePreviewMenu(
                        template: template,
                        onShare: shareTemplate,
                        onExport: exportTemplate,
                        onSelect: { onSelect(template); isPresented = false },
                        onCustomize: { showCustomizationSheet = true }
                    )
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
        }
        .onAppear {
            projectName = template.name
        }
        .sheet(isPresented: $showCustomizationSheet) {
            TemplateCustomizationView(
                template: template,
                projectName: $projectName,
                customizations: $customizations,
                isPresented: $showCustomizationSheet,
                onConfirm: { customizedTemplate in
                    onSelect(customizedTemplate)
                    isPresented = false
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func shareTemplate() {
        // テンプレート共有機能（将来実装）
    }
    
    private func exportTemplate() {
        // テンプレートエクスポート機能（将来実装）
    }
}

#Preview {
    @State var isPresented = true
    return TemplatePreviewView(
        template: ProjectTemplate.sampleTemplate,
        isPresented: $isPresented
    ) { _ in
        // Sample action
    }
}