import SwiftUI

struct ProjectOwnerSection: View {
    @Binding var selectedOwnerType: ProjectOwnerType
    @Binding var selectedFamilyId: String?
    @Binding var isUpdating: Bool
    let familyManager: FamilyManager?
    let onChangeOwner: () -> Void
    
    var body: some View {
        Section(header: Text("所有者")) {
            Picker("所有者タイプ", selection: $selectedOwnerType) {
                Text(ProjectOwnerType.individual.displayName).tag(ProjectOwnerType.individual)
                Text(ProjectOwnerType.family.displayName).tag(ProjectOwnerType.family)
            }
            .pickerStyle(.segmented)
            
            if selectedOwnerType == .family {
                if (familyManager?.families.isEmpty ?? true) {
                    Text("家族グループがありません。家族タブから作成/参加してください。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Picker("家族グループ", selection: Binding(get: { selectedFamilyId ?? "" }, set: { selectedFamilyId = $0.isEmpty ? nil : $0 })) {
                        Text("選択してください").tag("")
                        ForEach(familyManager?.families ?? []) { fam in
                            Text(fam.name).tag(fam.id ?? "")
                        }
                    }
                }
            }
            
            Button {
                onChangeOwner()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("所有者を変更")
                }
            }
            .disabled(isUpdating || (selectedOwnerType == .family && (selectedFamilyId ?? "").isEmpty))
        }
    }
}