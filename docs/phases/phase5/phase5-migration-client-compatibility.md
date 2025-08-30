# Phase 5: Client-Side Migration Compatibility
*Shigodeki Architecture Evolution - Session 5.1*

## Compatibility Layer Architecture

### Overview
The client-side compatibility layer enables seamless operation during migration, supporting both legacy family-based and new project-based data structures simultaneously.

---

## Core Compatibility Manager

### DataCompatibilityLayer
```swift
// iOS/shigodeki/Migration/DataCompatibilityLayer.swift
@MainActor
class DataCompatibilityLayer: ObservableObject {
    @Published var migrationState: MigrationState = .unknown
    @Published var migrationProgress: MigrationProgress?
    
    private let familyManager = FamilyManager()
    private let projectManager = ProjectManager()
    private let migrationService = MigrationService()
    
    enum MigrationState {
        case unknown
        case notMigrated
        case inProgress
        case migrated
        case failed
    }
    
    func checkMigrationStatus() async {
        do {
            let status = try await migrationService.getUserMigrationStatus()
            migrationState = status
        } catch {
            print("Failed to check migration status: \(error)")
            migrationState = .notMigrated
        }
    }
    
    func loadUserData() async {
        await checkMigrationStatus()
        
        switch migrationState {
        case .notMigrated:
            await familyManager.loadFamilies()
        case .migrated:
            await projectManager.loadProjects()
        case .inProgress:
            await trackMigrationProgress()
        default:
            break
        }
    }
}
```

### Migration Service
```swift
// iOS/shigodeki/Migration/MigrationService.swift
class MigrationService {
    private let functions = Functions.functions()
    private let db = Firestore.firestore()
    
    func getUserMigrationStatus() async throws -> DataCompatibilityLayer.MigrationState {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw MigrationError.notAuthenticated
        }
        
        let migrationDoc = try await db.collection("user_migrations").document(userId).getDocument()
        
        if !migrationDoc.exists {
            return .notMigrated
        }
        
        guard let status = migrationDoc.data()?["status"] as? String else {
            return .unknown
        }
        
        switch status {
        case "pending", "in_progress":
            return .inProgress
        case "completed":
            return .migrated
        case "failed":
            return .failed
        default:
            return .unknown
        }
    }
    
    func initiateMigration() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw MigrationError.notAuthenticated
        }
        
        let migrationFunction = functions.httpsCallable("migrationOrchestrator")
        
        do {
            _ = try await migrationFunction.call(["userId": userId])
        } catch {
            throw MigrationError.migrationFailed(error.localizedDescription)
        }
    }
}
```

---

## UI Compatibility Bridge

### Main Content Router
```swift
// iOS/shigodeki/Migration/MainContentRouter.swift
struct MainContentRouter: View {
    @StateObject private var compatibilityLayer = DataCompatibilityLayer()
    @State private var showMigrationPrompt = false
    
    var body: some View {
        Group {
            switch compatibilityLayer.migrationState {
            case .unknown:
                LoadingView("システム確認中...")
                
            case .notMigrated:
                LegacyMainView()
                    .migrationBanner(
                        isVisible: true,
                        onMigrate: {
                            showMigrationPrompt = true
                        }
                    )
                
            case .inProgress:
                MigrationProgressView(
                    progress: compatibilityLayer.migrationProgress
                )
                
            case .migrated:
                ProjectBasedMainView()
                
            case .failed:
                MigrationFailedView(
                    onRetry: {
                        await retryMigration()
                    }
                )
            }
        }
        .sheet(isPresented: $showMigrationPrompt) {
            MigrationPromptView(
                onConfirm: {
                    await startMigration()
                }
            )
        }
        .onAppear {
            await compatibilityLayer.loadUserData()
        }
    }
    
    private func startMigration() async {
        do {
            try await compatibilityLayer.migrationService.initiateMigration()
            await compatibilityLayer.checkMigrationStatus()
        } catch {
            // Handle migration error
            print("Migration failed: \(error)")
        }
    }
}
```

### Migration Banner
```swift
// iOS/shigodeki/Migration/MigrationBanner.swift
struct MigrationBanner: ViewModifier {
    let isVisible: Bool
    let onMigrate: () -> Void
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if isVisible {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("新機能が利用できます")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("プロジェクト管理とサブタスクが追加されました")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Button("アップグレード") {
                        onMigrate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.accentColor)
                .transition(.move(edge: .top))
            }
            
            content
        }
    }
}

extension View {
    func migrationBanner(isVisible: Bool, onMigrate: @escaping () -> Void) -> some View {
        self.modifier(MigrationBanner(isVisible: isVisible, onMigrate: onMigrate))
    }
}
```

---

## Legacy Data Managers (Preserved)

### Legacy Family Manager
```swift
// iOS/shigodeki/Legacy/LegacyFamilyManager.swift
@MainActor
class LegacyFamilyManager: ObservableObject {
    @Published var families: [Family] = []
    @Published var isLoading = false
    
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    func loadFamilies() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // Listen to legacy families collection
        listener = db.collection("families")
            .whereField("members", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error loading families: \(error)")
                    return
                }
                
                self.families = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Family.self)
                } ?? []
                
                self.isLoading = false
            }
    }
    
    deinit {
        listener?.remove()
    }
}
```

### Legacy UI Components
```swift
// iOS/shigodeki/Legacy/LegacyMainView.swift
struct LegacyMainView: View {
    @StateObject private var familyManager = LegacyFamilyManager()
    
    var body: some View {
        TabView {
            FamilyView()
                .environmentObject(familyManager)
                .tabItem {
                    Image(systemName: "house")
                    Text("家族")
                }
            
            TaskListMainView()
                .environmentObject(familyManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("タスク")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
        }
        .onAppear {
            await familyManager.loadFamilies()
        }
    }
}
```

---

## Migration UI Components

### Migration Progress View
```swift
// iOS/shigodeki/Migration/MigrationProgressView.swift
struct MigrationProgressView: View {
    let progress: MigrationProgress?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .rotationEffect(.degrees(progress?.isActive == true ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: progress?.isActive)
            
            VStack(spacing: 8) {
                Text("アップグレード中...")
                    .font(.headline)
                
                if let stage = progress?.currentStage {
                    Text(stage.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let progress = progress {
                ProgressView(value: progress.percentage)
                    .frame(width: 200)
            } else {
                ProgressView()
            }
            
            Text("この処理には数分かかる場合があります")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
```

### Migration Prompt
```swift
// iOS/shigodeki/Migration/MigrationPromptView.swift
struct MigrationPromptView: View {
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 12) {
                    Text("新機能へのアップグレード")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("プロジェクト管理機能とサブタスクが利用可能になります")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "folder", title: "プロジェクト管理", description: "タスクをプロジェクトとフェーズで整理")
                    FeatureRow(icon: "list.bullet.indent", title: "サブタスク", description: "大きなタスクを小さなステップに分割")
                    FeatureRow(icon: "person.3", title: "強化された共有", description: "より柔軟な権限管理システム")
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                VStack(spacing: 8) {
                    Text("⚠️ 重要")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("アップグレード中はアプリを閉じないでください。データは安全に移行されます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("アップグレード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("後で") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("開始") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
```

---

## Error Types and Handling

### Migration Errors
```swift
// iOS/shigodeki/Migration/MigrationErrors.swift
enum MigrationError: LocalizedError {
    case notAuthenticated
    case migrationFailed(String)
    case statusCheckFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "ユーザー認証が必要です"
        case .migrationFailed(let message):
            return "アップグレードに失敗しました: \(message)"
        case .statusCheckFailed:
            return "アップグレード状況を確認できませんでした"
        case .networkError:
            return "ネットワーク接続を確認してください"
        }
    }
}
```

---

*この互換性レイヤーにより、移行期間中もユーザーは中断されることなくアプリを使用でき、適切なタイミングで新機能に移行できます。*