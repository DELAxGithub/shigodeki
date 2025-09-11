import SwiftUI

/// Lightweight home hub showing quick links to Projects and Teams with one recent item each.
struct HomeHubView: View {
    @EnvironmentObject var sharedManagers: SharedManagerStore
    @EnvironmentObject var tabNavigation: TabNavigationManager
    
    @State private var recentProjectName: String? = nil
    @State private var recentFamilyName: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("ホーム")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Projects card
                    Button(action: goToProjects) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.primaryBlue.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: "folder.fill").foregroundColor(.primaryBlue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("プロジェクト一覧")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(recentProjectName.map { "最近: \($0)" } ?? "最近のプロジェクトなし")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Teams card
                    Button(action: goToFamilies) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.primaryBlue.opacity(0.15)).frame(width: 40, height: 40)
                                Image(systemName: "person.3.fill").foregroundColor(.primaryBlue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("チーム一覧")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(recentFamilyName.map { "最近: \($0)" } ?? "最近のチームなし")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
        }
        .task { await preloadAndPickRecents() }
    }
}

private extension HomeHubView {
    func goToProjects() {
        tabNavigation.selectedTab = tabNavigation.projectTabIndex
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .projectTabSelected, object: nil)
        }
    }
    func goToFamilies() {
        tabNavigation.selectedTab = tabNavigation.familyTabIndex
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .familyTabSelected, object: nil)
        }
    }
    
    func preloadAndPickRecents() async {
        // Projects
        let pm = await sharedManagers.getProjectManager()
        if let recent = pm.projects.sorted(by: { ($0.lastModifiedAt ?? $0.createdAt ?? .distantPast) > ($1.lastModifiedAt ?? $1.createdAt ?? .distantPast) }).first {
            await MainActor.run { recentProjectName = recent.name }
        }
        
        // Families
        let am = await sharedManagers.getAuthManager()
        let fm = await sharedManagers.getFamilyManager()
        if let uid = am.currentUser?.id, !uid.isEmpty {
            await fm.loadFamiliesForUser(userId: uid)
        }
        let fam = fm.families.sorted(by: { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }).first
        await MainActor.run { recentFamilyName = fam?.name }
    }
}

