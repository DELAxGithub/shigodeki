//
//  FamilyRepository.swift
//  shigodeki
//
//  Created for CTO DI Architecture Implementation
//  Issues #42, #43, #50 Root Fix: Repository Pattern with Dependency Injection
//

import Foundation
import Combine

/// Repository Protocol for Family Data Access
/// Abstracts data source (Firestore) from ViewModels for testability and scalability
protocol FamilyRepository {
    
    /// Real-time family data stream for authenticated user
    /// - Parameter userId: Authenticated user's ID
    /// - Returns: Publisher that emits family list updates in real-time
    func familiesPublisher(for userId: String) -> AnyPublisher<[Family], Error>
    
    /// Create new family
    /// - Parameters:
    ///   - name: Family name
    ///   - creatorUserId: User ID who creates the family
    /// - Returns: Created family ID
    func createFamily(name: String, creatorUserId: String) async throws -> String
    
    /// Join family via invitation
    /// - Parameters:
    ///   - userId: User ID joining the family
    ///   - invitationCode: Invitation code
    /// - Returns: Joined family information
    func joinFamily(userId: String, invitationCode: String) async throws -> JoinResult
    
    /// Leave family
    /// - Parameters:
    ///   - familyId: Family to leave
    ///   - userId: User leaving the family
    func leaveFamily(familyId: String, userId: String) async throws
    
    /// Stop all active listeners (cleanup)
    func stopListening()
}

/// Result type for family join operation
struct JoinResult {
    let familyId: String
    let familyName: String
    let message: String?
}