//
//  ProjectPhaseKPISection.swift
//  shigodeki
//
//  Displays per-phase KPI summaries on the project detail screen.
//

import SwiftUI

struct ProjectPhaseKPISection: View {
    let phaseKPIs: [ProjectPhaseKPIs]
    let phaseNameProvider: (String) -> String?
    let onOpenTask: (ProjectPhaseKPIs.TaskRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(phaseKPIs) { kpi in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(phaseNameProvider(kpi.phaseId) ?? "フェーズ: \(kpi.phaseId)")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(kpi.completion * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: kpi.completion)
                        .progressViewStyle(.linear)

                    if !kpi.blockers.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ブロッカー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(kpi.blockers) { task in
                                Button(task.title, action: { onOpenTask(task) })
                                    .buttonStyle(.borderless)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if !kpi.deps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("依存")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(kpi.deps.map { "\($0.phaseId): \($0.count)" }.joined(separator: ", "))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
