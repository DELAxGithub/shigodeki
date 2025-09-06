import SwiftUI

// MARK: - Create Project Sheets

struct CreateProjectSheets: ViewModifier {
    @Binding var showTemplateLibrary: Bool
    @Binding var showFileImporter: Bool
    @Binding var showAISettings: Bool
    @Binding var showProjectTypePicker: Bool
    @Binding var selectedTemplate: ProjectTemplate?
    @Binding var selectedProjectType: ProjectType?
    @Binding var projectName: String
    @Binding var selectedCreationMethod: CreateProjectView.CreationMethod
    @ObservedObject var aiGenerator: AITaskGenerator
    
    func body(content: Content) -> some View {
        content
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
            .sheet(isPresented: $showAISettings) {
                APISettingsView()
                    .onDisappear {
                        aiGenerator.updateAvailableProviders()
                    }
            }
            .sheet(isPresented: $showProjectTypePicker) {
                ProjectTypePickerView(
                    selectedType: $selectedProjectType
                )
            }
    }
}

extension View {
    func createProjectSheets(
        showTemplateLibrary: Binding<Bool>,
        showFileImporter: Binding<Bool>,
        showAISettings: Binding<Bool>,
        showProjectTypePicker: Binding<Bool>,
        selectedTemplate: Binding<ProjectTemplate?>,
        selectedProjectType: Binding<ProjectType?>,
        projectName: Binding<String>,
        selectedCreationMethod: Binding<CreateProjectView.CreationMethod>,
        aiGenerator: AITaskGenerator
    ) -> some View {
        modifier(CreateProjectSheets(
            showTemplateLibrary: showTemplateLibrary,
            showFileImporter: showFileImporter,
            showAISettings: showAISettings,
            showProjectTypePicker: showProjectTypePicker,
            selectedTemplate: selectedTemplate,
            selectedProjectType: selectedProjectType,
            projectName: projectName,
            selectedCreationMethod: selectedCreationMethod,
            aiGenerator: aiGenerator
        ))
    }
}