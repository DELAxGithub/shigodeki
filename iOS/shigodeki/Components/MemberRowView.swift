//
//  MemberRowView.swift
//  shigodeki
//
//  Extracted from FamilyDetailView.swift for better code organization
//  Displays a single family member row with role and remove functionality
//

import SwiftUI

struct MemberRowView: View {
    let member: User
    let isCreator: Bool
    let canRemove: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isCreator ? "crown.fill" : "person.circle.fill")
                .font(.title3)
                .foregroundColor(isCreator ? .orange : .blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.name)
                        .font(.headline)
                    
                    if isCreator {
                        Text("作成者")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                
                if let displayEmail = EmailDisplayUtility.displayableEmail(member.email) {
                    Text(displayEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let createdAt = member.createdAt {
                    // Issue #48 Fix: Show appropriate date label based on member role
                    let dateLabel = isCreator ? "作成日" : "参加日"
                    Text("\(dateLabel): \(DateFormatter.shortDate.string(from: createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}