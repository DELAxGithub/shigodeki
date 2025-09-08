//
//  InviteCodeView.swift
//  shigodeki
//
//  Extracted from FamilyDetailView.swift for better code organization
//  Shows family invite code with copy and share functionality
//

import SwiftUI

struct InviteCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String
    let familyName: String
    
    /// 統一システム対応表示ロジック（INV-はUI表示のみ）
    /// 永続化は素コードのみ、表示時にINV-を付与
    private var displayCode: String {
        // 統一システムでは素コードが渡されるため、UI表示時にINV-を付与
        if inviteCode.hasPrefix(InviteCodeSpec.displayPrefix) {
            // 既にINV-付きの場合（レガシー互換）
            return inviteCode
        } else {
            // 統一システムの素コード → INV-付きで表示
            return "\(InviteCodeSpec.displayPrefix)\(inviteCode)"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("招待コード")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("このコードを共有して\n「\(familyName)」にメンバーを招待しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    Text(displayCode)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .onTapGesture {
                            UIPasteboard.general.string = displayCode
                        }
                    
                    Text("タップしてコピー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        let activityVC = UIActivityViewController(
                            activityItems: ["家族グループ「\(familyName)」への招待コード: \(displayCode)"],
                            applicationActivities: nil
                        )
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController?.present(activityVC, animated: true)
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("招待コードを共有")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("招待コードの有効期限は30日間です")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("メンバーは「家族グループに加入」からこのコードを入力してグループに加入できます。\n統一システムにより安全文字のみ使用され、混同を防止します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("メンバーを招待")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}