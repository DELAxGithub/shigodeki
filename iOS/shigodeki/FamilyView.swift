//
//  FamilyView.swift
//  shigodeki
//
//  Created by Claude on 2025-08-27.
//

import SwiftUI

struct FamilyView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var familyManager = FamilyManager()
    @State private var showingCreateFamily = false
    @State private var showingJoinFamily = false
    
    var body: some View {
        NavigationView {
            VStack {
                if familyManager.families.isEmpty && !familyManager.isLoading {
                    // Empty state (when user has no families)
                    VStack(spacing: 24) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("家族グループがありません")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text("新しい家族グループを作成するか\n招待コードで参加しましょう")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                showingCreateFamily = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("家族グループを作成")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingJoinFamily = true
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("招待コードで参加")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                } else {
                    // Family list view (when user has families)
                    List {
                        ForEach(familyManager.families) { family in
                            NavigationLink(destination: FamilyDetailView(family: family)) {
                                FamilyRowView(family: family)
                            }
                        }
                    }
                    .refreshable {
                        if let userId = authManager.currentUser?.id {
                            await familyManager.loadFamiliesForUser(userId: userId)
                        }
                    }
                }
                
                if familyManager.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("家族")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !familyManager.families.isEmpty {
                        Button(action: {
                            showingJoinFamily = true
                        }) {
                            Image(systemName: "person.badge.plus")
                        }
                        
                        Button(action: {
                            showingCreateFamily = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onAppear {
                if let userId = authManager.currentUser?.id {
                    familyManager.startListeningToFamilies(userId: userId)
                    Task.detached {
                        await familyManager.loadFamiliesForUser(userId: userId)
                    }
                }
            }
            .onDisappear {
                familyManager.stopListeningToFamilies()
            }
            .sheet(isPresented: $showingCreateFamily) {
                CreateFamilyView(familyManager: familyManager)
            }
            .sheet(isPresented: $showingJoinFamily) {
                JoinFamilyView(familyManager: familyManager)
            }
            .alert("エラー", isPresented: .constant(familyManager.errorMessage != nil)) {
                Button("OK") {
                    familyManager.errorMessage = nil
                }
            } message: {
                Text(familyManager.errorMessage ?? "")
            }
        }
    }
}

struct FamilyRowView: View {
    let family: Family
    
    var body: some View {
        HStack {
            Image(systemName: "house.fill")
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(family.name)
                    .font(.headline)
                
                Text("\(family.members.count)人のメンバー")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                if let createdAt = family.createdAt {
                    Text("作成日: \(DateFormatter.shortDate.string(from: createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CreateFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var familyName: String = ""
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var invitationCode: String?
    
    @StateObject private var authManager = AuthenticationManager()
    let familyManager: FamilyManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("家族グループ名")
                        .font(.headline)
                    
                    TextField("例: 田中家", text: $familyName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                .padding(.horizontal)
                .padding(.top, 32)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: createFamily) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(isCreating ? "作成中..." : "家族グループを作成")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(familyName.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(familyName.isEmpty || isCreating)
                    
                    Button("キャンセル") {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("家族グループ作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("家族グループ作成完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("家族グループ「\(familyName)」が作成されました。")
            }
        }
    }
    
    private func createFamily() {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        isCreating = true
        
        Task.detached {
            do {
                _ = try await familyManager.createFamily(name: familyName, creatorUserId: userId)
                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
                print("Error creating family: \(error)")
            }
        }
    }
}

struct JoinFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var invitationCode: String = ""
    @State private var isJoining = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    @StateObject private var authManager = AuthenticationManager()
    let familyManager: FamilyManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("招待コード")
                        .font(.headline)
                    
                    TextField("6桁のコードを入力", text: $invitationCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .keyboardType(.numberPad)
                        .onChange(of: invitationCode) { _, newValue in
                            if newValue.count > 6 {
                                invitationCode = String(newValue.prefix(6))
                            }
                        }
                    
                    Text("家族から共有された6桁の招待コードを入力してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 32)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: joinFamily) {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(isJoining ? "参加中..." : "家族グループに参加")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(invitationCode.count == 6 ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(invitationCode.count != 6 || isJoining)
                    
                    Button("キャンセル") {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("家族グループに参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("参加完了", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    private func joinFamily() {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        isJoining = true
        
        Task.detached {
            do {
                let familyName = try await familyManager.joinFamilyWithCode(invitationCode, userId: userId)
                await MainActor.run {
                    isJoining = false
                    successMessage = "家族グループ「\(familyName)」に参加しました！"
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                }
                print("Error joining family: \(error)")
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

#Preview {
    FamilyView()
}