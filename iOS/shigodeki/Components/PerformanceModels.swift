//
//  PerformanceModels.swift
//  shigodeki
//
//  Extracted from IntegratedPerformanceMonitor.swift on 2025-09-07.
//

import Foundation

// MARK: - Performance Metrics

struct IntegratedPerformanceMetrics {
    let activeFirebaseListeners: Int
    let firebaseMemoryUsage: Double
    let activeManagers: Int
    let managerMemoryUsage: Double
    let currentFPS: Double
    let totalMemoryUsage: Double
    let cacheMemoryUsage: Double
    let overallScore: Double
    let timestamp: Date
    
    init() {
        self.activeFirebaseListeners = 0
        self.firebaseMemoryUsage = 0.0
        self.activeManagers = 0
        self.managerMemoryUsage = 0.0
        self.currentFPS = 60.0
        self.totalMemoryUsage = 0.0
        self.cacheMemoryUsage = 0.0
        self.overallScore = 100.0
        self.timestamp = Date()
    }
    
    init(activeFirebaseListeners: Int, firebaseMemoryUsage: Double, activeManagers: Int,
         managerMemoryUsage: Double, currentFPS: Double, totalMemoryUsage: Double,
         cacheMemoryUsage: Double, overallScore: Double, timestamp: Date) {
        self.activeFirebaseListeners = activeFirebaseListeners
        self.firebaseMemoryUsage = firebaseMemoryUsage
        self.activeManagers = activeManagers
        self.managerMemoryUsage = managerMemoryUsage
        self.currentFPS = currentFPS
        self.totalMemoryUsage = totalMemoryUsage
        self.cacheMemoryUsage = cacheMemoryUsage
        self.overallScore = overallScore
        self.timestamp = timestamp
    }
}

// MARK: - Performance Alerts

struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    let severity: Severity
    
    enum AlertType {
        case highMemoryUsage
        case lowFrameRate
        case excessiveListeners
        case systemMemoryWarning
    }
    
    enum Severity {
        case warning, critical
    }
}