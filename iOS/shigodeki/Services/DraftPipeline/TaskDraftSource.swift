//
//  TaskDraftSource.swift
//  shigodeki
//
//  Enumerates draft origins for unified preview pipeline.
//

import Foundation

enum TaskDraftSource: String, CaseIterable {
    case manual
    case ai
    case photo
    case template
}
