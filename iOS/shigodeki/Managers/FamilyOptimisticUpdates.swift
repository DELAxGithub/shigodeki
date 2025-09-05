import Foundation

// MARK: - Optimistic Updates Support

struct PendingOperation {
    let type: OperationType
    let originalData: Any?
    let timestamp: Date
    let retryCount: Int
    
    enum OperationType {
        case createFamily(tempId: String)
        case deleteFamily(familyId: String)
        case removeMember(familyId: String, userId: String)
        case joinFamily(familyId: String, userId: String)
    }
}

class FamilyOptimisticUpdatesManager {
    private var pendingOperations: [String: PendingOperation] = [:]
    private let pendingOperationTimeout: TimeInterval = 30.0
    private let maxRetryCount: Int = 3
    
    func cleanupExpiredOperations() {
        let now = Date()
        let expiredKeys = pendingOperations.keys.filter { key in
            guard let operation = pendingOperations[key] else { return true }
            return now.timeIntervalSince(operation.timestamp) > pendingOperationTimeout
        }
        
        for key in expiredKeys {
            if let operation = pendingOperations[key] {
                print("⚠️ Expired pending operation: \(operation.type)")
            }
            pendingOperations.removeValue(forKey: key)
        }
    }
    
    func createPendingOperation(type: PendingOperation.OperationType, originalData: Any? = nil) -> PendingOperation {
        return PendingOperation(
            type: type,
            originalData: originalData,
            timestamp: Date(),
            retryCount: 0
        )
    }
    
    func addPendingOperation(key: String, operation: PendingOperation) {
        cleanupExpiredOperations()
        pendingOperations[key] = operation
    }
    
    func removePendingOperation(key: String) {
        pendingOperations.removeValue(forKey: key)
    }
    
    func getPendingOperation(key: String) -> PendingOperation? {
        return pendingOperations[key]
    }
}