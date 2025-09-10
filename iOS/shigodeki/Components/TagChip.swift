//
//  TagChip.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import SwiftUI

// MARK: - TagChip Component

struct TagChip: View {
    // Internal properties - unified approach as per UX feedback
    private let displayName: String
    private let backgroundColor: Color
    private let foregroundColor: Color
    private let size: TagSize
    private let action: () -> Void
    
    // MARK: - TagSize Enum
    
    enum TagSize {
        case small
        case medium
        
        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            }
        }
    }
    
    // MARK: - Unified Initializer
    
    /// Unified initializer for all TagChip use cases
    /// - Parameters:
    ///   - tag: Optional TaskTag object for full tag information
    ///   - tagName: Simple string name when TaskTag object is not available
    ///   - size: Size variant (small/medium)
    ///   - isSelected: Whether the chip is in selected state
    ///   - action: Action to perform when tapped
    init(
        tag: TaskTag? = nil,
        tagName: String? = nil,
        size: TagSize = .medium,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.action = action
        
        // Determine display name
        if let tag = tag {
            self.displayName = tag.displayName
        } else if let tagName = tagName {
            self.displayName = tagName
        } else {
            self.displayName = "Unknown Tag"
        }
        
        // UX Improvement: Better accessibility with background-based states
        if isSelected {
            // Selected state: Full color background with white text
            if let tag = tag {
                self.backgroundColor = tag.swiftUIColor
                self.foregroundColor = .white
            } else {
                self.backgroundColor = .accentColor
                self.foregroundColor = .white
            }
        } else {
            // Unselected state: Light background with primary text for better readability
            if let tag = tag {
                self.backgroundColor = tag.swiftUIColor.opacity(0.2)
                self.foregroundColor = .primary
            } else {
                self.backgroundColor = Color.gray.opacity(0.2)
                self.foregroundColor = .primary
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            Text(displayName)
                .font(size.font)
                .foregroundColor(foregroundColor)
                .padding(size.padding)
                .background(backgroundColor)
                .cornerRadius(size.cornerRadius)
        }
        .buttonStyle(.plain)
        .interactiveEffect()
        .accessibilityLabel(displayName)
        .accessibilityHint("タグを選択")
    }
}

// MARK: - Convenience Initializers

extension TagChip {
    /// Convenience initializer for TaskTag objects
    init(
        tag: TaskTag,
        size: TagSize = .medium,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            tag: tag,
            tagName: nil,
            size: size,
            isSelected: isSelected,
            action: action
        )
    }
    
    /// Convenience initializer for simple tag names
    init(
        tagName: String,
        size: TagSize = .medium,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            tag: nil,
            tagName: tagName,
            size: size,
            isSelected: isSelected,
            action: action
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Sample tags for preview
        let sampleTag = TaskTag(
            name: "重要",
            color: "#FF3B30",
            emoji: "🔴",
            projectId: "project1",
            createdBy: "user1"
        )
        
        VStack(alignment: .leading, spacing: 8) {
            Text("TagChip Variants")
                .font(.headline)
            
            // Different states
            HStack(spacing: 8) {
                TagChip(tag: sampleTag, isSelected: false) {
                    print("Unselected tag tapped")
                }
                
                TagChip(tag: sampleTag, isSelected: true) {
                    print("Selected tag tapped")
                }
            }
            
            // Different sizes
            HStack(spacing: 8) {
                TagChip(tagName: "Small", size: .small, isSelected: false) {
                    print("Small tag tapped")
                }
                
                TagChip(tagName: "Medium", size: .medium, isSelected: false) {
                    print("Medium tag tapped")
                }
            }
            
            // String-based tags
            HStack(spacing: 8) {
                TagChip(tagName: "文字列タグ", isSelected: false) {
                    print("String tag tapped")
                }
                
                TagChip(tagName: "選択済み", isSelected: true) {
                    print("Selected string tag tapped")
                }
            }
        }
        
        Spacer()
    }
    .padding()
}
