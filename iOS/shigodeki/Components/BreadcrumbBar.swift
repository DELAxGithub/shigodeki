//
//  BreadcrumbBar.swift
//  shigodeki
//
//  Created by Claude on 2025-09-05.
//

import SwiftUI

struct BreadcrumbBar: View {
    let items: [String]
    var onTap: ((Int) -> Void)? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, label in
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(idx == items.count - 1 ? .primary : .secondary)
                        if idx < items.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(idx) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}