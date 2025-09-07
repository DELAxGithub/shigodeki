//
//  SectionPickerView.swift
//  shigodeki
//
//  SwiftUI component for phase section selection with Picker UI
//

import SwiftUI

struct SectionPickerView: View {
    let sections: [PhaseSection]
    @Binding var selectedSectionId: String?
    let onChange: ((String?) -> Void)?
    
    init(
        sections: [PhaseSection],
        selectedSectionId: Binding<String?>,
        onChange: ((String?) -> Void)? = nil
    ) {
        self.sections = sections
        self._selectedSectionId = selectedSectionId
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header - matching tag section style
            HStack {
                Text("セクション")
                    .font(.headline)
                
                Spacer()
            }
            
            // Section Content
            if sections.isEmpty {
                // Empty State - matching tag section style
                Text("セクションが設定されていません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .accessibilityLabel("No sections available for selection")
            } else {
                // Section Picker
                Menu {
                    // None option
                    Button(action: {
                        selectedSectionId = nil
                        onChange?(nil)
                    }) {
                        HStack {
                            Text("セクションなし")
                            Spacer()
                            if selectedSectionId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Section options
                    ForEach(sections.sorted(by: { $0.order < $1.order }), id: \.id) { section in
                        Button(action: {
                            selectedSectionId = section.id
                            onChange?(section.id)
                        }) {
                            HStack {
                                // Color indicator if available
                                if let colorHex = section.colorHex,
                                   let color = Color(hex: colorHex) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 12, height: 12)
                                }
                                
                                Text(section.name)
                                
                                Spacer()
                                
                                if selectedSectionId == section.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .accessibilityLabel("Section: \(section.name)")
                    }
                } label: {
                    HStack {
                        // Selected section display
                        if let selectedId = selectedSectionId,
                           let selectedSection = sections.first(where: { $0.id == selectedId }) {
                            // Show selected section with color
                            if let colorHex = selectedSection.colorHex,
                               let color = Color(hex: colorHex) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 12, height: 12)
                            }
                            
                            Text(selectedSection.name)
                                .font(.body)
                                .foregroundColor(.primary)
                        } else {
                            // Show "Select Section" placeholder
                            Text("セクションを選択")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("Section selector")
                .accessibilityHint("Choose a section for this task")
            }
        }
    }
}


// MARK: - Preview

#if DEBUG
struct SectionPickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with sections
            SectionPickerView(
                sections: [
                    PhaseSection(name: "計画立案", order: 1, colorHex: "007AFF"),
                    PhaseSection(name: "実装", order: 2, colorHex: "34C759"),
                    PhaseSection(name: "テスト", order: 3, colorHex: "FF9500")
                ],
                selectedSectionId: .constant("section1")
            )
            .previewDisplayName("With Sections")
            
            // Preview empty state
            SectionPickerView(
                sections: [],
                selectedSectionId: .constant(nil)
            )
            .previewDisplayName("Empty State")
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
#endif