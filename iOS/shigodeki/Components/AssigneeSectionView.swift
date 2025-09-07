//
//  AssigneeSectionView.swift
//  shigodeki
//
//  Component for task assignee selection with project members
//  Implements SwiftUI Picker for member assignment functionality
//

import SwiftUI

struct AssigneeSectionView: View {
    let members: [ProjectMember]
    @Binding var assignedTo: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("担当者")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "person.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Picker("担当者を選択", selection: $assignedTo) {
                Text("未割り当て")
                    .tag(nil as String?)
                
                ForEach(members, id: \.userId) { member in
                    Text(memberDisplayName(member))
                        .tag(member.userId as String?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if let assignedId = assignedTo,
               let assignedMember = members.first(where: { $0.userId == assignedId }) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("担当: \(memberDisplayName(assignedMember))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("担当者選択")
        .accessibilityHint("タスクの担当者を選択できます")
    }
    
    private func memberDisplayName(_ member: ProjectMember) -> String {
        return member.displayName ?? member.userId
    }
}

#Preview {
    let sampleMembers = [
        ProjectMember(userId: "user1", projectId: "project1", role: .owner, displayName: "田中太郎"),
        ProjectMember(userId: "user2", projectId: "project1", role: .editor, displayName: "佐藤花子"),
        ProjectMember(userId: "user3", projectId: "project1", role: .viewer)
    ]
    
    @State var selectedAssignee: String? = nil
    
    VStack {
        AssigneeSectionView(
            members: sampleMembers,
            assignedTo: $selectedAssignee
        )
        .padding()
        
        Divider()
        
        Text("Selected: \(selectedAssignee ?? "None")")
            .font(.caption)
            .padding()
    }
}