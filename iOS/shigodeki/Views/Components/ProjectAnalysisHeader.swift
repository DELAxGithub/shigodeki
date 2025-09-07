//
//  ProjectAnalysisHeader.swift
//  shigodeki
//
//  Extracted from ProjectAIAnalysisView.swift for CLAUDE.md compliance
//  Project analysis header component
//

import SwiftUI

struct ProjectAnalysisHeader: View {
    let project: Project
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI プロジェクト分析")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(project.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            
            Text("プロジェクトの状況を AI が分析し、具体的なアドバイスを提供します")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}