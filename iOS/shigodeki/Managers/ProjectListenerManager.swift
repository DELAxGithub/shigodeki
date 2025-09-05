//
//  ProjectListenerManager.swift
//  shigodeki
//
//  Extracted from ProjectManager.swift for better code organization
//

import Foundation
import FirebaseFirestore
import Combine

/// Handles all project real-time listener operations
@MainActor
class ProjectListenerManager: ObservableObject {
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    // Listener management
    private let listenerManager = FirebaseListenerManager.shared
    private var activeListenerIds: Set<String> = []
    private var currentUserId: String?
    
    // Pending create/update guard to avoid race where listener briefly reports 0 and clears UI
    private var pendingProjectTimestamps: [String: Date] = [:]
    private var lastLocalChangeAt: Date = .distantPast
    private let pendingTTL: TimeInterval = 5.0
    
    deinit {
        Task { @MainActor [weak self] in
            self?.removeAllListeners()
        }
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningForUserProjects(userId: String, onProjectsUpdated: @escaping ([Project]) -> Void) {
        guard !userId.isEmpty else {
            print("❌ ProjectListenerManager: Invalid userId for listener")
            return
        }
        print("🎧 ProjectListenerManager: Starting optimized listener for user: \(userId)")
        currentUserId = userId
        
        // 既存のユーザー向けリスナーを一旦解除（再構成のため）
        removeProjectListener()
        
        // 結果のマージ用ストレージ
        var map: [String: Project] = [:]
        var currentProjects: [Project] = []
        
        func applyMerged() {
            let now = Date()
            // TTLガード: 最近ローカル変更があり、受信が空なら維持
            let remoteList = Array(map.values)
            if remoteList.isEmpty && !currentProjects.isEmpty && now.timeIntervalSince(lastLocalChangeAt) < pendingTTL {
                print("⚠️ ProjectListenerManager: Ignoring empty merged snapshot due to TTL")
                return
            }
            // 既存とのマージ（ペンディング優先）
            var remoteMap: [String: Project] = [:]
            for p in remoteList { if let id = p.id { remoteMap[id] = p } }
            var merged: [Project] = []
            var seen = Set<String>()
            for cur in currentProjects {
                if let id = cur.id, var r = remoteMap[id] {
                    // Preserve local statistics if remote hasn't populated yet
                    if r.statistics == nil, let curStats = cur.statistics {
                        r.statistics = curStats
                    }
                    merged.append(r); seen.insert(id); remoteMap.removeValue(forKey: id)
                } else if let id = cur.id, let ts = pendingProjectTimestamps[id], now.timeIntervalSince(ts) < pendingTTL {
                    merged.append(cur)
                }
            }
            for (id, r) in remoteMap where !seen.contains(id) { merged.append(r) }
            if merged.isEmpty { merged = remoteList }
            currentProjects = merged
            onProjectsUpdated(merged)
            print("✅ ProjectListenerManager: Merged project list -> count=\(merged.count)")
        }
        
        // 1) 自分がメンバーのプロジェクト
        let idMember = "projects_member_\(userId)"
        let qMember = Firestore.firestore().collection("projects").whereField("memberIds", arrayContains: userId)
        let lidMember = listenerManager.createListener(id: idMember, query: qMember, type: .project, priority: .high) { [weak self] (result: Result<[Project], FirebaseError>) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let list):
                    for p in list { if let id = p.id { map[id] = p } }
                    self.isLoading = false
                    applyMerged()
                case .failure(let err):
                    print("❌ ProjectListenerManager: member-project listener error: \(err)")
                    self.error = err
                }
            }
        }
        activeListenerIds.insert(lidMember)
        
        // 2) 自分が所属するファミリーが所有するプロジェクト
        // ユーザーのfamilyIdsを取得（失敗時は無視）
        Task { @MainActor in
            do {
                let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
                let famIds = (userDoc.data()? ["familyIds"] as? [String]) ?? []
                for fid in famIds {
                    let idFam = "projects_family_\(fid)"
                    let qFam = Firestore.firestore().collection("projects").whereField("ownerId", isEqualTo: fid)
                    let lidFam = listenerManager.createListener(id: idFam, query: qFam, type: .project, priority: .medium) { [weak self] (res: Result<[Project], FirebaseError>) in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            switch res {
                            case .success(let list):
                                // ownerTypeがfamilyのものだけ採用
                                for p in list where p.ownerType == .family { if let id = p.id { map[id] = p } }
                                self.isLoading = false
                                applyMerged()
                            case .failure(let err):
                                print("❌ ProjectListenerManager: family-project listener error: \(err)")
                                self.error = err
                            }
                        }
                    }
                    self.activeListenerIds.insert(lidFam)
                }
            } catch {
                print("⚠️ ProjectListenerManager: Could not load user's familyIds (permissions?). Proceeding with member-only listener")
            }
        }
    }
    
    func startListeningForProject(id: String, onProjectUpdated: @escaping (Project?) -> Void) {
        guard !id.isEmpty else {
            print("❌ ProjectListenerManager: Invalid project ID for listener")
            return
        }
        
        let listenerId = "project_detail_\(id)"
        if activeListenerIds.contains(listenerId) {
            print("⚠️ ProjectListenerManager: Project listener already exists for: \(id)")
            return
        }
        
        print("🎧 ProjectListenerManager: Starting optimized project listener: \(id)")
        
        // 統合されたリスナー管理システムを使用
        let document = Firestore.firestore().collection("projects").document(id)
        let actualListenerId = listenerManager.createDocumentListener(
            id: listenerId,
            document: document,
            type: .project,
            priority: .medium
        ) { [weak self] (result: Result<Project?, FirebaseError>) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let project):
                    print("🔄 ProjectListenerManager: Optimized project listener received update")
                    onProjectUpdated(project)
                case .failure(let error):
                    print("❌ ProjectListenerManager: Optimized project listener error: \(error)")
                    self.error = error
                    onProjectUpdated(nil)
                }
            }
        }
        
        activeListenerIds.insert(actualListenerId)
    }
    
    func removeAllListeners() {
        print("🔄 ProjectListenerManager: Removing \(activeListenerIds.count) optimized listeners")
        
        // 統合されたリスナー管理システムで削除
        for listenerId in activeListenerIds {
            listenerManager.removeListener(id: listenerId)
        }
        
        activeListenerIds.removeAll()
        currentUserId = nil
        
        print("✅ ProjectListenerManager: All optimized listeners removed")
        
        // デバッグ情報の出力
        listenerManager.logDebugInfo()
    }
    
    // 特定のリスナーのみ削除
    func removeProjectListener() {
        if let userId = currentUserId {
            let listenerId = "projects_\(userId)"
            if activeListenerIds.contains(listenerId) {
                listenerManager.removeListener(id: listenerId)
                activeListenerIds.remove(listenerId)
                print("✅ ProjectListenerManager: Project list listener removed for user: \(userId)")
            }
        }
    }
    
    // 現在のプロジェクト詳細リスナーのみ削除
    func removeCurrentProjectListener() {
        let listenersToRemove = activeListenerIds.filter { $0.hasPrefix("project_detail_") }
        for listenerId in listenersToRemove {
            listenerManager.removeListener(id: listenerId)
            activeListenerIds.remove(listenerId)
        }
        print("✅ ProjectListenerManager: Project detail listeners removed")
    }
    
    // MARK: - Helper Methods
    
    func markPendingProject(_ projectId: String) {
        pendingProjectTimestamps[projectId] = Date()
        lastLocalChangeAt = Date()
    }
}