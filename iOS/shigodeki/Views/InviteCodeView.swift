//
//  InviteCodeView.swift
//  shigodeki
//
//  Extracted from FamilyDetailView.swift for better code organization
//  Shows family invite code with copy and share functionality
//

import SwiftUI
import UIKit

struct InviteCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String
    let familyName: String
    
    /// 表示ロジック: 常に素コードのみ表示（INV-は付けない）
    private var displayCode: String {
        // 入力がINV-付きでも素コードだけを見せる
        if let normalized = try? InvitationCodeNormalizer.normalize(inviteCode) {
            return normalized
        }
        // フォールバック: 単純に先頭INV-を除去
        let prefix = InviteCodeSpec.displayPrefix
        if inviteCode.hasPrefix(prefix) { return String(inviteCode.dropFirst(prefix.count)) }
        return inviteCode
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
                    
                    ShareLink(item: "家族グループ『\(familyName)』の招待コード: \(displayCode)") {
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
