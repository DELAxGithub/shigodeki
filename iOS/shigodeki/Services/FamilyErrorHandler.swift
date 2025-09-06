//
//  FamilyErrorHandler.swift
//  shigodeki
//
//  Created by Claude on 2025-01-04.
//

import Foundation

struct FamilyErrorHandler {
    
    // MARK: - Error Processing
    
    /// Processes Firebase errors and provides detailed logging
    static func handleFirestoreError(_ error: NSError) -> FirebaseError {
        print("🛑 [FATAL] FamilyErrorHandler: Firestore error. Code: \(error.code)")
        print("🛑 [FATAL] Firestore Error Domain: \(error.domain)")
        print("🛑 [FATAL] Firestore Error Description: \(error.localizedDescription)")
        print("🛑 [FATAL] Firestore Error UserInfo: \(error.userInfo)")
        
        // FirestoreErrorCode specific logging
        switch error.code {
        case 7: // PERMISSION_DENIED
            print("🛑 [FATAL] PERMISSION_DENIED: Check Firestore Security Rules")
        case 14: // UNAVAILABLE  
            print("🛑 [FATAL] UNAVAILABLE: Firebase service temporarily unavailable")
        case 4: // DEADLINE_EXCEEDED
            print("🛑 [FATAL] DEADLINE_EXCEEDED: Request timed out")
        case 5: // NOT_FOUND
            print("🛑 [FATAL] NOT_FOUND: Document or collection not found")
        default:
            print("🛑 [FATAL] Unknown Firestore error code: \(error.code)")
        }
        
        return FirebaseError.from(error)
    }
    
    /// Handles general NSError cases
    static func handleNSError(_ error: NSError) -> FirebaseError {
        print("🛑 [FATAL] FamilyErrorHandler: Non-Firestore NSError")
        print("🛑 [FATAL] Error Domain: \(error.domain)")
        print("🛑 [FATAL] Error Code: \(error.code)")
        print("🛑 [FATAL] Error Description: \(error.localizedDescription)")
        print("🛑 [FATAL] Error UserInfo: \(error.userInfo)")
        
        return FirebaseError.from(error)
    }
    
    /// Handles unknown errors
    static func handleUnknownError(_ error: Error) -> FirebaseError {
        print("🛑 [FATAL] FamilyErrorHandler: Unknown error")
        print("🛑 [FATAL] Error type: \(type(of: error))")
        print("🛑 [FATAL] Error description: \(error.localizedDescription)")
        
        return FirebaseError.unknownError(error)
    }
    
    // MARK: - Rollback Operations
    
    /// Performs rollback for failed optimistic updates
    static func performOptimisticRollback(
        families: inout [Family],
        temporaryId: String,
        familyName: String,
        showCreateSuccess: inout Bool,
        showCreateProcessing: inout Bool,
        processingMessage: inout String
    ) {
        print("🛑 [ROLLBACK] FamilyErrorHandler: Removing temporary family '\(familyName)' due to error.")
        families.removeAll { $0.id == temporaryId }
        showCreateSuccess = false
        showCreateProcessing = false
        processingMessage = ""
    }
}