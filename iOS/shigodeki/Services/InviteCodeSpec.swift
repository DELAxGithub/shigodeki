//
//  InviteCodeSpec.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation

/// 統一招待コード仕様 - KISS原則の体現
/// Over-engineering撲滅：単一真実源、曖昧変換廃止
struct InviteCodeSpec {
    
    // MARK: - 統一定数（単一真実源）
    
    /// 表示用接頭辞（UIのみ、永続化しない）
    static let displayPrefix = "INV-"
    
    /// コード桁数（将来8桁拡張予定、後方互換維持）
    static let codeLength = 6
    
    /// 安全文字セット（混同文字完全除外）
    /// O/I/L/0/1 除外でユーザビリティ向上
    static let safeCharacters = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    
    /// 安全文字正規表現（厳密検証）
    static let safeCodeRegex = "^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$"
    
    // MARK: - レガシー互換（段階的廃止予定）
    
    /// レガシー数字のみ正規表現（既存データ用）
    static let legacyRegex = "^[0-9]{6}$"
    
    // MARK: - 統一検証API
    
    /// 安全文字コードの形式チェック
    /// - Parameter code: チェック対象のコード  
    /// - Returns: 安全文字形式なら true
    static func isValidSafeFormat(_ code: String) -> Bool {
        return code.range(of: safeCodeRegex, options: .regularExpression) != nil
    }
    
    /// レガシー数字コードの形式チェック（後方互換）
    /// - Parameter code: チェック対象のコード
    /// - Returns: 数字形式なら true
    static func isValidLegacyFormat(_ code: String) -> Bool {
        return code.range(of: legacyRegex, options: .regularExpression) != nil
    }
    
    /// コード桁数チェック
    /// - Parameter code: チェック対象のコード
    /// - Returns: 正しい桁数なら true
    static func hasCorrectLength(_ code: String) -> Bool {
        return code.count == codeLength
    }
    
    /// 統一形式検証（安全文字優先、レガシー後方互換）
    /// - Parameter code: チェック対象のコード
    /// - Returns: 検証結果
    static func validate(_ code: String) -> ValidationResult {
        if code.isEmpty {
            return .failure(.empty)
        }
        
        if !hasCorrectLength(code) {
            return .failure(.invalidLength(code.count))
        }
        
        // 安全文字セット優先
        if isValidSafeFormat(code) {
            return .success(.safe(code))
        }
        
        // レガシー互換（段階的廃止予定）
        if isValidLegacyFormat(code) {
            return .success(.legacy(code))
        }
        
        return .failure(.invalidCharacters)
    }
    
    /// 検証結果の型
    enum ValidationResult {
        case success(InviteCodeType)
        case failure(ValidationError)
        
        var isValid: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }
        
        var codeType: InviteCodeType? {
            switch self {
            case .success(let type): return type
            case .failure: return nil
            }
        }
    }
    
    /// 統一招待コード種別
    enum InviteCodeType {
        case safe(String)     // 安全文字6桁（推奨）
        case legacy(String)   // 数字6桁（後方互換）
        
        var code: String {
            switch self {
            case .safe(let code): return code
            case .legacy(let code): return code
            }
        }
        
        var displayFormat: String {
            switch self {
            case .safe(let code): return "\(displayPrefix)\(code)"
            case .legacy(let code): return code  // レガシーはプレフィックスなし
            }
        }
        
        var isSafe: Bool {
            switch self {
            case .safe: return true
            case .legacy: return false
            }
        }
    }
    
    /// 検証エラーの種類
    enum ValidationError {
        case empty
        case invalidLength(Int)
        case invalidCharacters
        
        var localizedDescription: String {
            switch self {
            case .empty:
                return "招待コードを入力してください"
            case .invalidLength(let length):
                return "招待コードは\(InviteCodeSpec.codeLength)桁で入力してください（入力: \(length)桁）"
            case .invalidCharacters:
                return "招待コードは安全文字のみ使用できます（O/I/L/0/1は使用不可）"
            }
        }
    }
}