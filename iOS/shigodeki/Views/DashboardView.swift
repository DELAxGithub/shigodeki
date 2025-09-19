//
//  DashboardView.swift
//  shigodeki
//
//  Presents a dashboard-first experience summarising personal workload and
//  pending drafts. Designed to stay lightweight and avoid duplicating
//  Firestore listeners.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var sharedManagers: SharedManagerStore
    @EnvironmentObject private var tabNavigation: TabNavigationManager
    @EnvironmentObject private var toast: ToastCenter
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTask: DashboardTaskSummary?
    @State private var showingQuickAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    assignmentsCard
                    if FeatureFlags.previewAIEnabled {
                        aiDraftCard
                    }
                    quickActionsCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("ダッシュボード")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .navigationDestination(item: $selectedTask) { summary in
            DashboardTaskDetailView(summary: summary)
                .environmentObject(sharedManagers)
        }
        .sheet(isPresented: $showingQuickAdd) {
            DashboardQuickAddSheet()
                .environmentObject(tabNavigation)
        }
        .onAppear {
            viewModel.triggerRefresh()
        }
        .onChange(of: showingQuickAdd) { _, isPresented in
            if !isPresented {
                viewModel.triggerRefresh()
            }
        }
        .onChange(of: selectedTask) { _, newValue in
            if newValue == nil {
                viewModel.triggerRefresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.triggerRefresh()
            }
        }
    }

    // MARK: - Cards

    private var assignmentsCard: some View {
        DashboardCard(title: "アサインされたタスク", subtitle: subtitleForAssignments, count: viewModel.myTasks.count) {
            if viewModel.isLoadingAssignments {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("タスクを読み込み中...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if viewModel.myTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今すぐ取り組むタスクはありません")
                        .foregroundColor(.secondary)
                    Button {
                        tabNavigation.selectedTab = tabNavigation.projectTabIndex
                    } label: {
                        Label("プロジェクトへ移動", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("DashboardCard.Assignments.EmptyCTA")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.myTasks.prefix(5)) { summary in
                        Button {
                            selectedTask = summary
                        } label: {
                            DashboardTaskRow(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.myTasks.count > 5 {
                        Button {
                            tabNavigation.selectedTab = tabNavigation.projectTabIndex
                        } label: {
                            Label("すべて表示", systemImage: "arrow.forward")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("DashboardCard.Assignments.ShowAll")
                    }
                }
            }
        }
        .accessibilityLabel("アサインされたタスク \(viewModel.myTasks.count) 件")
    }

    private var aiDraftCard: some View {
        DashboardCard(title: "AIドラフト", subtitle: aiSubtitle, count: viewModel.aiDrafts.count) {
            if viewModel.aiDrafts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AIからの提案はまだありません")
                        .foregroundColor(.secondary)
                    Button {
                        showingQuickAdd = true
                    } label: {
                        Label("AIアシスタントで依頼", systemImage: "brain")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("DashboardCard.AI.EmptyCTA")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.aiDrafts.prefix(3)) { draft in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            if let rationale = draft.rationale, !rationale.isEmpty {
                                Text(rationale)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }

                    HStack(spacing: 12) {
                        Button {
                            showingQuickAdd = true
                        } label: {
                            Label("AIアシスタントを開く", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            viewModel.markAIDraftsConsumed()
                            toast.show("AI下書きの表示をクリアしました")
                        } label: {
                            Label("クリア", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("DashboardCard.AI.Clear")
                    }
                }
            }
        }
        .accessibilityLabel("AIドラフト \(viewModel.aiDrafts.count) 件")
    }

    private var quickActionsCard: some View {
        DashboardCard(title: "クイック操作", subtitle: "よく使う機能にすばやくアクセス", count: nil) {
            VStack(spacing: 12) {
                Button {
                    showingQuickAdd = true
                } label: {
                    DashboardQuickActionRow(icon: "plus", title: "作業を追加", description: "AI・写真・テンプレから新しいタスクを作成")
                }
                .buttonStyle(.plain)

                Button {
                    tabNavigation.selectedTab = tabNavigation.projectTabIndex
                } label: {
                    DashboardQuickActionRow(icon: "folder", title: "プロジェクトを管理", description: "フェーズの確認や並べ替えを行う")
                }
                .buttonStyle(.plain)

                Button {
                    tabNavigation.selectedTab = tabNavigation.familyTabIndex
                } label: {
                    DashboardQuickActionRow(icon: "person.3", title: "チームを確認", description: "招待コードやメンバーの状態をチェック")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var subtitleForAssignments: String {
        if viewModel.isLoadingAssignments { return "読み込み中" }
        if let first = viewModel.myTasks.first, let due = first.task.dueDate {
            let formatter = DateFormatter.taskDueDate
            return "次の期限: \(formatter.string(from: due))"
        }
        return "今週の担当タスク"
    }

    private var aiSubtitle: String {
        viewModel.aiDrafts.isEmpty ? "AIからの下書きを依頼できます" : "レビュー待ちの提案を表示"
    }

}

// MARK: - Components

private struct DashboardCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let count: Int?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .transition(.opacity)
                }
            }

            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .contain)
    }
}

private struct DashboardTaskRow: View {
    let summary: DashboardTaskSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.task.title)
                    .font(.body.bold())
                    .foregroundColor(.primary)
                Text(summary.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let due = summary.task.dueDate {
                    HStack(spacing: 6) {
                        Image(systemName: summary.task.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                            .foregroundColor(summary.task.isOverdue ? .error : .secondary)
                        Text(summary.task.isOverdue ? "期限超過: \(DateFormatter.taskDueDate.string(from: due))" : "期限: \(DateFormatter.taskDueDate.string(from: due))")
                            .font(.caption)
                            .foregroundColor(summary.task.isOverdue ? .error : .secondary)
                    }
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(summary.task.priority.displayName)
                    .font(.caption.bold())
                    .foregroundColor(summary.task.priority.swiftUIColor)
                if summary.task.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.task.title)、\(summary.subtitle)")
    }
}

private struct DashboardQuickActionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(.primaryBlue)
                .frame(width: 28, height: 28)
                .background(Color.primaryBlue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DashboardQuickAddSheet: View {
    @EnvironmentObject var tabNavigation: TabNavigationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("タスクを追加") {
                    Button {
                        dismissAndNavigate(to: tabNavigation.projectTabIndex) {
                            NotificationCenter.default.post(name: .projectTabSelected, object: nil)
                        }
                    } label: {
                        Label("作業の追加モーダルを開く", systemImage: "square.and.pencil")
                    }
                    Button {
                        dismissAndNavigate(to: tabNavigation.projectTabIndex)
                    } label: {
                        Label("AIアシスタントへ", systemImage: "brain")
                    }
                    Button {
                        dismissAndNavigate(to: tabNavigation.projectTabIndex)
                    } label: {
                        Label("テンプレートから追加", systemImage: "doc.text")
                    }
                }
                Section("共有") {
                    Button {
                        dismissAndNavigate(to: tabNavigation.familyTabIndex)
                    } label: {
                        Label("チームにメンバーを招待", systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle("クイック操作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func dismissAndNavigate(to tabIndex: Int, afterDismiss: (() -> Void)? = nil) {
        let action = {
            tabNavigation.selectedTab = tabIndex
            afterDismiss?()
        }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: action)
    }
}
