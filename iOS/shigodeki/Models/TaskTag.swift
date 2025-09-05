//
//  TaskTag.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - TaskTag Model

struct TaskTag: Identifiable, Codable, Hashable, Equatable {
    var id: String?
    var name: String
    var displayName: String
    var color: String  // Hex color code
    var emoji: String?
    var familyId: String
    var usageCount: Int
    var createdAt: Date?
    var createdBy: String
    var lastUsedAt: Date?
    
    init(name: String, color: String, emoji: String? = nil, familyId: String, createdBy: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = emoji != nil ? "\(emoji!) \(self.name)" : self.name
        self.color = color
        self.emoji = emoji
        self.familyId = familyId
        self.createdBy = createdBy
        self.usageCount = 0
        self.createdAt = Date()
        self.lastUsedAt = nil
    }
    
    // MARK: - Computed Properties
    
    var swiftUIColor: Color {
        Color(hex: color) ?? Color.accentColor
    }
    
    var isUnused: Bool {
        usageCount == 0
    }
    
    var lastUsedFormatted: String? {
        guard let lastUsedAt = lastUsedAt else { return nil }
        return DateFormatter.taskDueDate.string(from: lastUsedAt)
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TaskTag, rhs: TaskTag) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Firestore Methods
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "displayName": displayName,
            "color": color,
            "familyId": familyId,
            "usageCount": usageCount,
            "createdBy": createdBy,
            "createdAt": createdAt ?? Date()
        ]
        
        if let emoji = emoji {
            data["emoji"] = emoji
        }
        
        if let lastUsedAt = lastUsedAt {
            data["lastUsedAt"] = lastUsedAt
        }
        
        return data
    }
    
    static func fromFirestoreData(_ data: [String: Any], documentId: String) -> TaskTag? {
        guard let name = data["name"] as? String,
              let color = data["color"] as? String,
              let familyId = data["familyId"] as? String,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        var tag = TaskTag(
            name: name,
            color: color,
            emoji: data["emoji"] as? String,
            familyId: familyId,
            createdBy: createdBy
        )
        
        tag.id = documentId
        // ALWAYS use Firestore displayName if available to prevent duplication
        // If not available, the init will have already generated the correct displayName
        if let firestoreDisplayName = data["displayName"] as? String, 
           !firestoreDisplayName.isEmpty {
            tag.displayName = firestoreDisplayName
        }
        tag.usageCount = data["usageCount"] as? Int ?? 0
        
        if let timestamp = data["createdAt"] as? Timestamp {
            tag.createdAt = timestamp.dateValue()
        }
        
        if let timestamp = data["lastUsedAt"] as? Timestamp {
            tag.lastUsedAt = timestamp.dateValue()
        }
        
        return tag
    }
}

// MARK: - Default Tag Colors

extension TaskTag {
    static let defaultColors = [
        "#007AFF", // Blue
        "#FF3B30", // Red  
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#34C759", // Green
        "#5AC8FA", // Light Blue
        "#AF52DE", // Purple
        "#FF2D92", // Pink
        "#8E8E93", // Gray
        "#A2845E"  // Brown
    ]
    
    static func randomColor() -> String {
        defaultColors.randomElement() ?? "#007AFF"
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        // Validate hex string
        guard !hex.isEmpty else { return nil }
        
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        // Validate color component values to prevent NaN
        let redValue = Double(r) / 255.0
        let greenValue = Double(g) / 255.0
        let blueValue = Double(b) / 255.0
        let opacityValue = Double(a) / 255.0
        
        guard redValue.isFinite && greenValue.isFinite && 
              blueValue.isFinite && opacityValue.isFinite &&
              redValue >= 0.0 && redValue <= 1.0 &&
              greenValue >= 0.0 && greenValue <= 1.0 &&
              blueValue >= 0.0 && blueValue <= 1.0 &&
              opacityValue >= 0.0 && opacityValue <= 1.0 else {
            return nil
        }

        self.init(
            .sRGB,
            red: redValue,
            green: greenValue,
            blue: blueValue,
            opacity: opacityValue
        )
    }
}

// MARK: - TagError

enum TagError: Error, LocalizedError {
    case invalidName
    case duplicateName
    case notFound
    case creationFailed(String)
    case updateFailed(String)
    case deletionFailed(String)
    case loadingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "タグ名が無効です"
        case .duplicateName:
            return "同じ名前のタグが既に存在します"
        case .notFound:
            return "タグが見つかりません"
        case .creationFailed(let message):
            return "タグの作成に失敗しました: \(message)"
        case .updateFailed(let message):
            return "タグの更新に失敗しました: \(message)"
        case .deletionFailed(let message):
            return "タグの削除に失敗しました: \(message)"
        case .loadingFailed(let message):
            return "タグの読み込みに失敗しました: \(message)"
        }
    }
}