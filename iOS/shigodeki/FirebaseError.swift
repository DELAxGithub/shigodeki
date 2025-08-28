//
//  FirebaseError.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import Foundation
import FirebaseFirestore

enum FirebaseError: LocalizedError {
    case networkError
    case permissionDenied
    case documentNotFound
    case invalidData
    case operationFailed(String)
    case validationError(ValidationError)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "ネットワークエラーが発生しました。接続を確認してください。"
        case .permissionDenied:
            return "この操作を実行する権限がありません。"
        case .documentNotFound:
            return "指定されたデータが見つかりませんでした。"
        case .invalidData:
            return "データの形式が正しくありません。"
        case .operationFailed(let message):
            return "操作が失敗しました: \(message)"
        case .validationError(let validationError):
            return validationError.localizedDescription
        case .unknownError(let error):
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    static func from(_ error: Error) -> FirebaseError {
        if let firestoreError = error as NSError? {
            switch firestoreError.code {
            case FirestoreErrorCode.unavailable.rawValue:
                return .networkError
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .permissionDenied
            case FirestoreErrorCode.notFound.rawValue:
                return .documentNotFound
            case FirestoreErrorCode.invalidArgument.rawValue:
                return .invalidData
            default:
                return .unknownError(error)
            }
        } else if let validationError = error as? ValidationError {
            return .validationError(validationError)
        } else {
            return .unknownError(error)
        }
    }
}

protocol FirebaseOperationProtocol {
    associatedtype Model: Codable & Identifiable
    
    func create(_ model: Model) async throws -> Model
    func read(id: String) async throws -> Model?
    func update(_ model: Model) async throws -> Model
    func delete(id: String) async throws
    func list() async throws -> [Model]
}

actor FirebaseOperationBase<Model: Codable & Identifiable> {
    private let collection: CollectionReference
    private let decoder = Firestore.Decoder()
    private let encoder = Firestore.Encoder()
    
    init(collectionPath: String) {
        self.collection = Firestore.firestore().collection(collectionPath)
    }
    
    func create(_ model: Model) async throws -> Model {
        var mutableModel = model
        let documentRef = collection.document()
        
        // Use reflection to set the id if possible
        if var idSetter = mutableModel as? any _IdSettable {
            idSetter.setId(documentRef.documentID)
            mutableModel = idSetter as! Model
        }
        
        do {
            try await documentRef.setData(try encoder.encode(mutableModel))
            return mutableModel
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func read(id: String) async throws -> Model? {
        do {
            let document = try await collection.document(id).getDocument()
            guard document.exists else {
                return nil
            }
            return try document.data(as: Model.self, decoder: decoder)
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func update(_ model: Model) async throws -> Model {
        guard let id = model.id as? String else {
            throw FirebaseError.invalidData
        }
        
        do {
            try await collection.document(id).setData(try encoder.encode(model), merge: true)
            return model
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func delete(id: String) async throws {
        do {
            try await collection.document(id).delete()
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func list() async throws -> [Model] {
        do {
            let snapshot = try await collection.getDocuments()
            return try snapshot.documents.compactMap { document in
                try document.data(as: Model.self, decoder: decoder)
            }
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func list(where field: String, isEqualTo value: Any) async throws -> [Model] {
        do {
            let snapshot = try await collection.whereField(field, isEqualTo: value).getDocuments()
            return try snapshot.documents.compactMap { document in
                try document.data(as: Model.self, decoder: decoder)
            }
        } catch {
            throw FirebaseError.from(error)
        }
    }
    
    func listen(completion: @escaping (Result<[Model], FirebaseError>) -> Void) -> ListenerRegistration {
        return collection.addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(FirebaseError.from(error)))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            do {
                let models = try documents.compactMap { document in
                    try document.data(as: Model.self, decoder: Firestore.Decoder())
                }
                completion(.success(models))
            } catch {
                completion(.failure(FirebaseError.from(error)))
            }
        }
    }
    
    func listen(where field: String, isEqualTo value: Any, completion: @escaping (Result<[Model], FirebaseError>) -> Void) -> ListenerRegistration {
        return collection.whereField(field, isEqualTo: value).addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(FirebaseError.from(error)))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            do {
                let models = try documents.compactMap { document in
                    try document.data(as: Model.self, decoder: Firestore.Decoder())
                }
                completion(.success(models))
            } catch {
                completion(.failure(FirebaseError.from(error)))
            }
        }
    }
}

private protocol _IdSettable {
    mutating func setId(_ id: String)
}

extension Project: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension Phase: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension TaskList: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension ShigodekiTask: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension Subtask: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension User: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension ProjectInvitation: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}

extension ProjectMember: _IdSettable {
    mutating func setId(_ id: String) {
        self.id = id
    }
}