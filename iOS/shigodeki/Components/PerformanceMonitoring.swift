//
//  PerformanceMonitoring.swift
//  shigodeki
//
//  Extracted from PerformanceOptimization.swift for CLAUDE.md compliance
//  Performance monitoring and metrics collection system
//

import SwiftUI
import Combine

// MARK: - Performance Monitoring

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private var frameTimer: Timer?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime > 0 {
            let fps = 1.0 / deltaTime
            metrics.currentFPS = min(fps, 60.0)
        }
        
        lastFrameTime = currentTime
        
        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            metrics.memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }
    
    deinit {
        frameTimer?.invalidate()
    }
}

struct PerformanceMetrics {
    var currentFPS: Double = 60.0
    var memoryUsageMB: Double = 0.0
    
    var isPerformanceGood: Bool {
        return currentFPS > 55.0 && memoryUsageMB < 150.0
    }
    
    var performanceLevel: PerformanceLevel {
        switch (currentFPS, memoryUsageMB) {
        case (55...60, 0..<100):
            return .excellent
        case (45...55, 0..<150):
            return .good
        case (30...45, 0..<200):
            return .fair
        default:
            return .poor
        }
    }
}

enum PerformanceLevel {
    case excellent, good, fair, poor
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Debounced Search

class DebouncedSearch: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init(debounceTime: TimeInterval = 0.5) {
        $searchText
            .debounce(for: .seconds(debounceTime), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.debouncedSearchText = value
            }
            .store(in: &cancellables)
    }
    
    func clearSearch() {
        searchText = ""
        debouncedSearchText = ""
    }
}

// MARK: - Memory Warning Handler

extension View {
    func onMemoryWarning(perform action: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
        ) { _ in
            action()
        }
    }
}

// MARK: - Performance Debug View

struct PerformanceDebugView: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(monitor.metrics.performanceLevel.color)
                    .frame(width: 12, height: 12)
                Text("Performance: \(monitor.metrics.performanceLevel.description)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                Text("FPS: \(String(format: "%.1f", monitor.metrics.currentFPS))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Memory: \(String(format: "%.1f MB", monitor.metrics.memoryUsageMB))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}