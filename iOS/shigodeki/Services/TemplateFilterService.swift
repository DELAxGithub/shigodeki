import Foundation

// MARK: - Template Filter Service

class TemplateFilterService {
    
    enum SortOption: String, CaseIterable {
        case name = "名前"
        case category = "カテゴリ"
        case difficulty = "難易度"
        case recent = "最新"
        
        var systemImage: String {
            switch self {
            case .name: return "textformat.abc"
            case .category: return "folder"
            case .difficulty: return "star"
            case .recent: return "clock"
            }
        }
    }
    
    static func filterAndSort(
        templates: [ProjectTemplate],
        selectedCategory: TemplateCategory? = nil,
        searchText: String = "",
        sortOption: SortOption = .name
    ) -> [ProjectTemplate] {
        var filteredTemplates = templates
        
        // Category filter
        if let selectedCategory = selectedCategory {
            filteredTemplates = filteredTemplates.filter { $0.category == selectedCategory }
        }
        
        // Search filter
        if !searchText.isEmpty {
            filteredTemplates = filteredTemplates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description?.localizedCaseInsensitiveContains(searchText) == true ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Sort
        switch sortOption {
        case .name:
            filteredTemplates.sort { $0.name < $1.name }
        case .category:
            filteredTemplates.sort { $0.category.displayName < $1.category.displayName }
        case .difficulty:
            filteredTemplates.sort { 
                let stars1 = $0.difficulty?.stars ?? 0
                let stars2 = $1.difficulty?.stars ?? 0
                return stars1 < stars2
            }
        case .recent:
            filteredTemplates.sort { 
                $0.updatedAt > $1.updatedAt
            }
        }
        
        return filteredTemplates
    }
}