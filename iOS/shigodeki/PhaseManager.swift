//
//  PhaseManager.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class PhaseManager: ObservableObject {
    @Published var phases: [Phase] = []
    @Published var currentPhase: Phase?
    @Published var isLoading = false
    @Published var error: FirebaseError?
    
    private var listeners: [ListenerRegistration] = []
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Phase CRUD Operations
    
    func createPhase(name: String, description: String? = nil, projectId: String, createdBy: String, order: Int? = nil) async throws -> Phase {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let finalOrder = order ?? (try await getNextPhaseOrder(projectId: projectId))
            var phase = Phase(name: name, description: description, projectId: projectId, createdBy: createdBy, order: finalOrder)
            
            try phase.validate()
            
            let phaseCollection = Firestore.firestore().collection("projects").document(projectId).collection("phases")
            let documentRef = phaseCollection.document()
            phase.id = documentRef.documentID
            phase.createdAt = Date()
            
            try await documentRef.setData(try Firestore.Encoder().encode(phase))
            
            return phase
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getPhase(id: String, projectId: String) async throws -> Phase? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let phaseDoc = Firestore.firestore().collection("projects").document(projectId).collection("phases").document(id)
            let snapshot = try await phaseDoc.getDocument()
            
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: Phase.self)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func getPhases(projectId: String) async throws -> [Phase] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let phasesCollection = Firestore.firestore().collection("projects").document(projectId).collection("phases")
            let snapshot = try await phasesCollection.order(by: "order").getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: Phase.self)
            }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func updatePhase(_ phase: Phase) async throws -> Phase {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try phase.validate()
            
            let phaseDoc = Firestore.firestore().collection("projects").document(phase.projectId).collection("phases").document(phase.id ?? "")
            try await phaseDoc.setData(try Firestore.Encoder().encode(phase), merge: true)
            
            // Update local state
            if currentPhase?.id == phase.id {
                currentPhase = phase
            }
            
            if let index = phases.firstIndex(where: { $0.id == phase.id }) {
                phases[index] = phase
            }
            
            return phase
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    func deletePhase(id: String, projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Delete all task lists in this phase first
            let taskListManager = TaskListManager()
            let taskLists = try await taskListManager.getTaskLists(phaseId: id, projectId: projectId)
            
            for taskList in taskLists {
                try await taskListManager.deleteTaskList(id: taskList.id ?? "", phaseId: id, projectId: projectId)
            }
            
            // Delete the phase
            let phaseDoc = Firestore.firestore().collection("projects").document(projectId).collection("phases").document(id)
            try await phaseDoc.delete()
            
            // Update local state
            phases.removeAll { $0.id == id }
            if currentPhase?.id == id {
                currentPhase = nil
            }
            
            // Reorder remaining phases
            try await reorderPhases(projectId: projectId)
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    // MARK: - Phase Ordering
    
    private func getNextPhaseOrder(projectId: String) async throws -> Int {
        let phases = try await getPhases(projectId: projectId)
        return phases.map { $0.order }.max() ?? 0 + 1
    }
    
    func reorderPhases(_ phases: [Phase], projectId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let batch = Firestore.firestore().batch()
            
            for (index, phase) in phases.enumerated() {
                var updatedPhase = phase
                updatedPhase.order = index
                
                let phaseRef = Firestore.firestore().collection("projects").document(projectId).collection("phases").document(phase.id ?? "")
                try batch.setData(try Firestore.Encoder().encode(updatedPhase), forDocument: phaseRef, merge: true)
            }
            
            try await batch.commit()
            self.phases = phases.sorted { $0.order < $1.order }
        } catch {
            let firebaseError = FirebaseError.from(error)
            self.error = firebaseError
            throw firebaseError
        }
    }
    
    private func reorderPhases(projectId: String) async throws {
        let currentPhases = try await getPhases(projectId: projectId)
        let reorderedPhases = currentPhases.enumerated().map { index, phase in
            var updatedPhase = phase
            updatedPhase.order = index
            return updatedPhase
        }
        try await reorderPhases(reorderedPhases, projectId: projectId)
    }
    
    // MARK: - Phase Completion
    
    func markPhaseComplete(id: String, projectId: String) async throws {
        guard var phase = try await getPhase(id: id, projectId: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        phase.isCompleted = true
        phase.completedAt = Date()
        
        _ = try await updatePhase(phase)
    }
    
    func markPhaseIncomplete(id: String, projectId: String) async throws {
        guard var phase = try await getPhase(id: id, projectId: projectId) else {
            throw FirebaseError.documentNotFound
        }
        
        phase.isCompleted = false
        phase.completedAt = nil
        
        _ = try await updatePhase(phase)
    }
    
    // MARK: - Real-time Listeners
    
    func startListeningForPhases(projectId: String) {
        let phasesCollection = Firestore.firestore().collection("projects").document(projectId).collection("phases")
        
        let listener = phasesCollection.order(by: "order").addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.phases = []
                    return
                }
                
                do {
                    let phases = try documents.compactMap { document in
                        try document.data(as: Phase.self)
                    }
                    self?.phases = phases
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
    
    func startListeningForPhase(id: String, projectId: String) {
        let phaseDoc = Firestore.firestore().collection("projects").document(projectId).collection("phases").document(id)
        
        let listener = phaseDoc.addSnapshotListener { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = FirebaseError.from(error)
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    self?.currentPhase = nil
                    return
                }
                
                do {
                    let phase = try document.data(as: Phase.self)
                    self?.currentPhase = phase
                } catch {
                    self?.error = FirebaseError.from(error)
                }
            }
        }
        
        listeners.append(listener)
    }
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Validation Helpers
    
    func validatePhaseHierarchy(phase: Phase) async throws {
        let taskListManager = TaskListManager()
        let taskLists = try await taskListManager.getTaskLists(phaseId: phase.id ?? "", projectId: phase.projectId)
        try ModelRelationships.validatePhaseHierarchy(phase: phase, taskLists: taskLists)
    }
}