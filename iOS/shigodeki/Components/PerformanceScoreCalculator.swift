//
//  PerformanceScoreCalculator.swift
//  shigodeki
//
//  Extracted from IntegratedPerformanceMonitor.swift on 2025-09-07.
//

import Foundation

// MARK: - Performance Score Calculator

struct PerformanceScoreCalculator {
    
    /// パフォーマンス総合スコアを計算
    /// - Parameters:
    ///   - listenerCount: アクティブなFirebaseリスナー数
    ///   - memoryUsage: 総メモリ使用量(MB)
    ///   - fps: 現在のFPS
    ///   - managerCount: アクティブなManager数
    /// - Returns: 0-100のスコア値
    static func calculateOverallScore(
        listenerCount: Int,
        memoryUsage: Double,
        fps: Double,
        managerCount: Int
    ) -> Double {
        var score = 100.0
        
        // Firebase リスナー数による減点
        let listenerScore = Double(listenerCount)
        score -= max(0, (listenerScore - 8.0) * 5.0) // 8個超過で1個あたり5点減点
        
        // メモリ使用量による減点
        score -= max(0, (memoryUsage - 150.0) * 0.5) // 150MB超過で1MBあたり0.5点減点
        
        // FPSによる減点
        score -= max(0, (55.0 - fps) * 2.0) // 55fps未満で1fpsあたり2点減点
        
        // Manager数による減点
        let managerScore = Double(managerCount)
        score -= max(0, (managerScore - 12.0) * 3.0) // 12個超過で1個あたり3点減点
        
        return max(0, min(100, score))
    }
}