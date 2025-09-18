//
//  KPIRefreshScheduler.swift
//  shigodeki
//
//  Coordinates KPI refresh triggers with throttling.
//

import Foundation
import Combine
import UIKit

@MainActor
final class KPIRefreshScheduler: ObservableObject {
    static let shared = KPIRefreshScheduler()

    private var lastRefresh: Date?
    private var cancellables: Set<AnyCancellable> = []
    private var scheduledTask: Task<Void, Never>?

    func register(handler: @escaping () -> Void) {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.schedule(handler: handler) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.schedule(handler: handler) }
            .store(in: &cancellables)
    }

    func schedule(handler: @escaping () -> Void) {
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            guard let self = self else { return }
            if let last = lastRefresh, Date().timeIntervalSince(last) < 60 { return }
            self.lastRefresh = Date()
            handler()
        }
    }
}

