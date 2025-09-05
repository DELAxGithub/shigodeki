//
//  TemplateCustomizationView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-29.
//

import SwiftUI

struct TemplateCustomizationView: View {
    let template: ProjectTemplate
    @Binding var projectName: String
    @Binding var customizations: ProjectCustomizations
    @Binding var isPresented: Bool
    let onConfirm: (ProjectTemplate) -> Void
    
    @State private var selectedProjectSettings = ProjectSettings()
    @State private var skipOptionalTasks = false
    @State private var selectedTaskPriorityOverrides: [String: TaskPriority] = [:]
    @State private var selectedPhaseColors: [String: TaskListColor] = [:]
    @State private var customDescription = ""
    @State private var showAdvancedOptions = false
    
    private var stats: TemplateStats {
        TemplateCustomizationService.calculateStats(for: template)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TemplateOverviewSection(template: template, stats: stats)
                    
                    ProjectSettingsSection(
                        projectName: $projectName,
                        customDescription: $customDescription,
                        selectedProjectSettings: $selectedProjectSettings
                    )
                    
                    TaskOptionsSection(
                        skipOptionalTasks: $skipOptionalTasks,
                        showAdvancedOptions: $showAdvancedOptions,
                        stats: stats
                    )
                    
                    if showAdvancedOptions {
                        advancedOptionsSection
                    }
                    
                    TemplatePreviewSection(
                        projectName: projectName,
                        customDescription: customDescription,
                        selectedProjectSettings: selectedProjectSettings,
                        skipOptionalTasks: skipOptionalTasks,
                        selectedPhaseColors: selectedPhaseColors,
                        selectedTaskPriorityOverrides: selectedTaskPriorityOverrides,
                        stats: stats
                    )
                }
                .padding()
            }
            .navigationTitle("テンプレートカスタマイズ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    isPresented = false
                },
                trailing: Button("作成") {
                    createCustomizedProject()
                }
                .fontWeight(.semibold)
            )
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    @ViewBuilder
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "高度なカスタマイズ", icon: "slider.horizontal.3")
            
            VStack(spacing: 20) {
                PhaseColorCustomizationSection(
                    template: template,
                    selectedPhaseColors: $selectedPhaseColors
                )
                
                TaskPriorityCustomizationSection(
                    template: template,
                    selectedTaskPriorityOverrides: $selectedTaskPriorityOverrides
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialValues() {
        selectedProjectSettings = TemplateCustomizationService.createInitialProjectSettings()
    }
    
    private func createCustomizedProject() {
        let finalCustomizations = ProjectCustomizations(
            projectSettings: selectedProjectSettings,
            skipOptionalTasks: skipOptionalTasks,
            phaseStartDelays: [:],
            taskPriorityOverrides: selectedTaskPriorityOverrides,
            customPhaseColors: selectedPhaseColors
        )
        
        let customizedTemplate = TemplateCustomizationService.applyCustomizations(
            to: template,
            projectName: projectName,
            customDescription: customDescription,
            customizations: finalCustomizations
        )
        
        onConfirm(customizedTemplate)
    }
}

// MARK: - Preview

#Preview {
    TemplateCustomizationView(
        template: SoftwareDevTemplates.sampleWebsiteTemplate,
        projectName: .constant("カスタムWebサイト"),
        customizations: .constant(ProjectCustomizations()),
        isPresented: .constant(true),
        onConfirm: { _ in }
    )
}