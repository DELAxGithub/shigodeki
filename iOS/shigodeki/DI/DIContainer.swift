//
//  DIContainer.swift
//  shigodeki
//
//  Created for CTO DI Architecture Implementation
//  Simple Dependency Injection Container - No external libraries required
//

import Foundation

/// Simple Dependency Injection Container
/// CTO REQUIREMENT: Type-based dependency resolution for testability and scalability
class DIContainer {
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
    // MARK: - Private Storage
    
    private var registrations: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    private init() {}
    
    // MARK: - Registration Methods
    
    /// Register a singleton instance for a protocol type
    /// - Parameters:
    ///   - type: Protocol type to register
    ///   - instance: Concrete instance implementing the protocol
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        registrations[key] = instance
        print("✅ DIContainer: Registered singleton instance for \(key)")
    }
    
    /// Register a factory function for a protocol type
    /// - Parameters:
    ///   - type: Protocol type to register
    ///   - factory: Factory function that creates instances
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
        print("✅ DIContainer: Registered factory for \(key)")
    }
    
    // MARK: - Resolution Methods
    
    /// Resolve a dependency by type
    /// - Parameter type: Protocol type to resolve
    /// - Returns: Instance implementing the protocol
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        // First try singleton instances
        if let instance = registrations[key] as? T {
            print("🔍 DIContainer: Resolved singleton instance for \(key)")
            return instance
        }
        
        // Then try factories
        if let factory = factories[key] {
            let instance = factory() as! T
            print("🔍 DIContainer: Created instance from factory for \(key)")
            return instance
        }
        
        // Fallback error
        fatalError("❌ DIContainer: No registration found for type \(key). Make sure to register this type in setupDependencies()")
    }
    
    /// Optional resolve - returns nil if not registered
    /// - Parameter type: Protocol type to resolve
    /// - Returns: Instance implementing the protocol, or nil
    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        if let instance = registrations[key] as? T {
            print("🔍 DIContainer: Resolved optional singleton for \(key)")
            return instance
        }
        
        if let factory = factories[key] {
            let instance = factory() as! T
            print("🔍 DIContainer: Created optional instance from factory for \(key)")
            return instance
        }
        
        print("⚠️ DIContainer: No registration found for optional type \(key)")
        return nil
    }
    
    // MARK: - Utility Methods
    
    /// Check if a type is registered
    /// - Parameter type: Type to check
    /// - Returns: True if registered
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return registrations[key] != nil || factories[key] != nil
    }
    
    /// Clear all registrations (for testing)
    func clearAllRegistrations() {
        registrations.removeAll()
        factories.removeAll()
        print("🧹 DIContainer: All registrations cleared")
    }
    
    /// Get debug information about registered types
    func debugInfo() -> String {
        var info = "📊 DIContainer Debug Info:\n"
        info += "Singleton instances: \(registrations.keys.joined(separator: ", "))\n"
        info += "Factories: \(factories.keys.joined(separator: ", "))"
        return info
    }
}

// MARK: - App Setup Extension

extension DIContainer {
    
    /// Setup all dependencies for the application
    /// CTO REQUIREMENT: Register concrete implementations at app startup
    func setupDependencies() {
        print("🚀 DIContainer: Setting up application dependencies")
        
        // Register Repository implementations using factory to avoid MainActor issues
        register(FamilyRepository.self, factory: {
            return FirestoreFamilyRepository()
        })
        
        // Register other repositories here when implemented
        // register(ProjectRepository.self, instance: FirestoreProjectRepository())
        // register(TaskRepository.self, instance: FirestoreTaskRepository())
        
        print("✅ DIContainer: Application dependencies setup completed")
        print(debugInfo())
    }
}