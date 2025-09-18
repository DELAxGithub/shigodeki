//
//  PortfolioKPIHeader.swift
//  shigodeki
//
//  Header view for portfolio KPI dashboards.
//

import SwiftUI

struct PortfolioKPIHeader: View {
    let state: KPIState
    let onRefresh: () -> Void

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .loading:
            loadingView
        case .ready(let kpis, let isStale):
            contentView(kpis: kpis, isStale: isStale)
        case .failed:
            failedView
        }
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(height: 12)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("KPI 読み込み中")
    }

    private func contentView(kpis: PortfolioKPIs, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("期限切れ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(kpis.overdue)")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("KPI を更新")
            }

            SparklineView(points: kpis.completionTrend)
                .frame(height: 40)

            DeadlineHeatmapView(bins: kpis.deadlineHeatmap)
                .frame(height: 60)

            HStack {
                if isStale {
                    Text("更新: \(RelativeDateTimeFormatter().localizedString(for: kpis.updatedAt, relativeTo: Date()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var failedView: some View {
        VStack(spacing: 8) {
            Label("KPIの取得に失敗しました", systemImage: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Button("再読み込み", action: onRefresh)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sparkline

private struct SparklineView: View {
    let points: [PortfolioKPIs.CompletionSample]

    var body: some View {
        GeometryReader { proxy in
            let values = points.map { max(0, min(1, $0.completion)) }
            let maxValue = max(values.max() ?? 1, 0.01)
            let minValue = min(values.min() ?? 0, 1)
            let range = max(maxValue - minValue, 0.01)

            Path { path in
                for (index, point) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                    let normalized = (point - minValue) / range
                    let y = proxy.size.height * (1 - CGFloat(normalized))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.primaryBlue, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }
}

// MARK: - Heatmap

private struct DeadlineHeatmapView: View {
    let bins: [PortfolioKPIs.HeatmapBin]

    private let urgencies = [0, 1, 2]

    private struct WeekKey: Identifiable, Hashable {
        let year: Int
        let week: Int

        var id: String { "\(year)-\(week)" }
    }

    var body: some View {
        let grouped = Dictionary(grouping: bins) { WeekKey(year: $0.year, week: $0.weekOfYear) }
        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            if lhs.year == rhs.year { return lhs.week < rhs.week }
            return lhs.year < rhs.year
        }
        let keys = Array(sortedKeys.suffix(4))

        return HStack(alignment: .center, spacing: 6) {
            ForEach(keys) { key in
                let binsForWeek = grouped[key] ?? []
                VStack(spacing: 4) {
                    Text("W\(key.week)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(urgencies, id: \.self) { urgency in
                        let count = binsForWeek.first(where: { $0.urgency == urgency })?.count ?? 0
                        Rectangle()
                            .fill(color(for: urgency).opacity(opacity(for: count)))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text(count > 0 ? "\(count)" : "")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
    }

    private func color(for urgency: Int) -> Color {
        switch urgency {
        case 0: return Color.primaryBlue
        case 1: return Color.orange
        default: return Color.error
        }
    }

    private func opacity(for count: Int) -> Double {
        guard count > 0 else { return 0.2 }
        return min(0.2 + Double(count) * 0.15, 1.0)
    }
}
