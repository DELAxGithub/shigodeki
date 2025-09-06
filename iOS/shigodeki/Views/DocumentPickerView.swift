//
//  DocumentPickerView.swift
//  shigodeki
//
//  Refactored for CLAUDE.md compliance - Core UIViewController wrapper only
//  UI components extracted to DocumentPickerComponents.swift
//  Service logic extracted to TemplateImportService.swift
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    let onDocumentPicked: (URL) -> Void
    let allowedTypes: [UTType]
    let allowsMultipleSelection: Bool
    
    init(isPresented: Binding<Bool>, 
         allowedTypes: [UTType] = [.json], 
         allowsMultipleSelection: Bool = false,
         onDocumentPicked: @escaping (URL) -> Void) {
        self._isPresented = isPresented
        self.allowedTypes = allowedTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onDocumentPicked = onDocumentPicked
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.shouldShowFileExtensions = true
        
        // iOS 14以降でのカスタマイゼーション
        if #available(iOS 14.0, *) {
            picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // 必要に応じてアップデート処理
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}