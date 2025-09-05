//
//  StorageManager.swift
//  shigodeki
//
//  Created by Codex on 2025-08-30.
//

import Foundation
import FirebaseStorage

class StorageManager {
    static let shared = StorageManager()
    private init() {}
    
    private let storage = Storage.storage()
    
    /// Uploads image data to Firebase Storage and returns a download URL string
    func uploadImage(data: Data, projectId: String, taskId: String, fileName: String = UUID().uuidString + ".jpg") async throws -> String {
        let ref = storage.reference().child("projects/\(projectId)/tasks/\(taskId)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

extension StorageReference {
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { cont in
            self.putData(uploadData, metadata: metadata) { meta, error in
                if let error = error { cont.resume(throwing: error) } else { cont.resume(returning: meta ?? StorageMetadata()) }
            }
        }
    }
}

