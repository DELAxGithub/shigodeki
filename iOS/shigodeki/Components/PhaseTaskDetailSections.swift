//
//  PhaseTaskDetailSections.swift
//  shigodeki
//
//  Small UI components extracted from PhaseTaskDetailView for readability and faster type-checking
//

import SwiftUI
import PhotosUI

struct AssigneeSectionView: View {
    let members: [ProjectMember]
    @Binding var assignedTo: String?
    
    var body: some View {
        Picker("担当者", selection: $assignedTo) {
            Text("未指定").tag(String?.none)
            ForEach(members, id: \.userId) { member in
                Text(member.displayName ?? String(member.userId.prefix(6))).tag(Optional(member.userId))
            }
        }
    }
}

struct TagsSectionView: View {
    @Binding var tags: [String]
    @Binding var newTagText: String
    var onAdd: (String) -> Void
    var onRemove: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("タグ").font(.subheadline); Spacer() }
            WrapTagsView(tags: tags, onRemove: onRemove)
            HStack {
                TextField("タグを追加", text: $newTagText)
                    .submitLabel(.done)
                    .onSubmit { onAdd(newTagText) }
                Button("追加") { onAdd(newTagText) }
                    .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct SectionPickerView: View {
    let sections: [PhaseSection]
    @Binding var selectedSectionId: String?
    var onChange: (String?) -> Void
    var body: some View {
        Picker("セクション", selection: Binding(get: { selectedSectionId }, set: { selectedSectionId = $0; onChange($0) })) {
            Text("未分類").tag(String?.none)
            ForEach(sections, id: \.id) { sec in
                if let sid = sec.id { Text(sec.name).tag(Optional(sid)) }
            }
        }
    }
}

struct AttachmentsSectionView: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var localImages: [UIImage]
    var onImageData: (Data) async -> Void
    var body: some View {
        Section("添付画像") {
            if !localImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(localImages.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                }
            }
            PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                Label("画像を追加", systemImage: "photo.on.rectangle")
            }
            .onChange(of: selectedPhotos) { _, items in
                Task { @MainActor in
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            localImages.append(img)
                            await onImageData(data)
                        }
                    }
                }
            }
        }
    }
}

