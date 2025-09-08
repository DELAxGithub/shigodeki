//
//  InvitationCodeNormalizer.swift
//  shigodeki
//
//  Created by Claude on 2025-09-07.
//

import Foundation

/// 統一招待コード正規化 - 曖昧変換廃止、許容外即エラー
/// KISS原則：シンプル、安全、確実
struct InvitationCodeNormalizer {
    
    /// 統一正規化処理 - 曖昧変換完全廃止
    /// - Parameter input: ユーザー入力文字列
    /// - Returns: 正規化結果（INV-接頭辞除去済み）
    /// - Throws: InvalidCharacterError（許容外文字検出時）
    static func normalize(_ input: String) throws -> String {
        // Step 1: 基本クリーンアップ
        var result = input.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? result
        result = result.uppercased()
        result = result.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        
        // Step 2: INV-接頭辞除去（表示分離）
        if result.hasPrefix("INV") {
            result = String(result.dropFirst(3))
        }
        
        // Step 3: 許容外文字検証（曖昧変換廃止）
        let allowedChars = Set(InviteCodeSpec.safeCharacters + "0123456789")
        for char in result {
            if !allowedChars.contains(char) {
                throw NormalizationError.invalidCharacter(char)
            }
        }
        
        return result
    }
    
    /// 安全な招待コード分類（エラーハンドリング強化）
    /// - Parameter input: ユーザー入力文字列
    /// - Returns: 分類結果
    /// - Throws: NormalizationError
    static func classify(_ input: String) throws -> InviteCodeSpec.InviteCodeType? {
        let normalized = try normalize(input)
        
        // 安全文字セット優先
        if InviteCodeSpec.isValidSafeFormat(normalized) {
            return .safe(normalized)
        }
        
        // レガシー互換
        if InviteCodeSpec.isValidLegacyFormat(normalized) {
            return .legacy(normalized)
        }
        
        return nil
    }
    
    /// 診断用正規化ログ（デバッグ・監査対応）
    /// - Parameter input: 入力文字列
    /// - Returns: 正規化結果、分類結果、詳細ログ
    static func normalizeWithDiagnostics(_ input: String) -> NormalizationResult {
        let step1 = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let step2 = step1.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? step1
        let step3 = step2.uppercased()
        let step4 = step3.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        
        var step5 = step4
        if step5.hasPrefix("INV") {
            step5 = String(step5.dropFirst(3))
        }
        
        var error: NormalizationError?
        var classification: InviteCodeSpec.InviteCodeType?
        
        do {
            classification = try classify(input)
        } catch let normalizationError as NormalizationError {
            error = normalizationError
        } catch let caughtError {
            error = .unknown(caughtError.localizedDescription)
        }
        
        let log = """
        === 統一正規化診断 ===
        入力: "\(input)"
        Step 1 (空白除去): "\(step1)"
        Step 2 (全角→半角): "\(step2)"  
        Step 3 (大文字化): "\(step3)"
        Step 4 (空白・ハイフン除去): "\(step4)"
        Step 5 (INV-除去): "\(step5)"
        分類: \(classification?.displayFormat ?? "無効")
        エラー: \(error?.localizedDescription ?? "なし")
        """
        
        return NormalizationResult(
            normalized: step5,
            classification: classification,
            error: error,
            diagnostics: log
        )
    }
}

// MARK: - 統一エラー定義

/// 正規化エラー（曖昧変換廃止により明確化）
enum NormalizationError: LocalizedError {
    case invalidCharacter(Character)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCharacter(let char):
            return "使用できない文字が含まれています: '\(char)' (O/I/L/0/1は使用不可)"
        case .unknown(let message):
            return "正規化エラー: \(message)"
        }
    }
}

/// 正規化結果（診断情報付き）
struct NormalizationResult {
    let normalized: String
    let classification: InviteCodeSpec.InviteCodeType?
    let error: NormalizationError?
    let diagnostics: String
    
    var isValid: Bool {
        return error == nil && classification != nil
    }
}