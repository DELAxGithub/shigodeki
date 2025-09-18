//
//  KPIState.swift
//  shigodeki
//
//  View-facing state for KPI dashboard surfaces.
//

import Foundation

enum KPIState {
    case hidden
    case loading
    case ready(kpis: PortfolioKPIs, isStale: Bool)
    case failed
}

