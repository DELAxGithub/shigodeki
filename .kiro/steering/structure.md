# Project Structure - シゴデキ (Shigodeki)

**Inclusion Mode**: Always (Loaded in every interaction)

## Root Directory Organization

```
shigodeki/
├── .kiro/                          # Kiro spec-driven development framework
│   ├── steering/                   # Project steering documents (this directory)
│   └── specs/                      # Feature specifications (future)
├── iOS/                            # iOS application and testing infrastructure
│   ├── shigodeki/                  # Main iOS application source
│   ├── shigodeki.xcodeproj/        # Xcode project configuration
│   ├── Firebase/                   # Firebase configuration and scripts
│   ├── test/                       # Node.js-based Firebase testing
│   └── node_modules/               # Testing dependencies
├── docs/                           # Project documentation
├── scripts/                        # Utility scripts and tools
├── .github/                        # GitHub configuration and templates
└── CLAUDE.md                       # Claude Code project instructions
```

## iOS Application Structure

### Primary Source Directory (`iOS/shigodeki/`)

```
iOS/shigodeki/
├── Components/                     # Reusable UI components (64 files)
├── Views/                          # SwiftUI views and screens (61 files)
├── Models/                         # Data models and entities (16 files)
├── Services/                       # Business logic and external integrations (95 files)
├── Managers/                       # Application state and coordination (30 files)
├── ViewModels/                     # View models for MVVM pattern (10 files)
├── Repository/                     # Data access layer (4 files)
├── AI/                            # AI-related functionality (8 files)
├── Extensions/                     # Swift extensions (3 files)
├── DI/                            # Dependency injection (3 files)
├── Debug/                         # Debug utilities (3 files)
├── Assets.xcassets/               # App assets and resources
├── shigodeki.xcdatamodeld/        # Core Data model (legacy)
├── shigodekiApp.swift             # Main app entry point
├── Info.plist                     # App configuration
├── GoogleService-Info.plist       # Firebase configuration
└── shigodeki.entitlements         # App capabilities
```

## Code Organization Patterns

### Layer Architecture
The application follows a clear layered architecture:

```
Presentation Layer (Views + Components)
         ↓
Business Logic Layer (ViewModels + Services)
         ↓
Data Access Layer (Repository + Managers)
         ↓
External Services (Firebase, AI Services)
```

### Component-Based Architecture
- **Atomic Components**: Small, reusable UI elements (buttons, inputs, cards)
- **Composite Components**: Complex components built from atomic ones
- **View Components**: Screen-specific components that don't need reuse
- **System Components**: Infrastructure components (accessibility, performance, etc.)

### Service Layer Organization
```
Services/
├── Core Services/                  # Fundamental app services
├── Business Logic/                 # Domain-specific business rules
├── External Integrations/          # Third-party service integrations
├── AI Services/                    # AI-powered functionality
└── Utility Services/               # Helper and utility functions
```

## File Naming Conventions

### Views and Components
- **Views**: `[Feature][Purpose]View.swift` (e.g., `ProjectDetailView.swift`)
- **Components**: `[Entity]Components.swift` or `[Purpose]Components.swift`
- **Row Components**: `[Entity]RowView.swift` (e.g., `ProjectRowView.swift`)
- **Section Components**: `[Feature]Sections.swift` (e.g., `TaskBasicSections.swift`)

### Models and Data
- **Models**: `[Entity].swift` (e.g., `Project.swift`, `Family.swift`)
- **Extensions**: `[Entity]Extensions.swift` or `[Feature]Extensions.swift`
- **Managers**: `[Domain]Manager.swift` (e.g., `ProjectManager.swift`)
- **Services**: `[Domain]Service.swift` (e.g., `AuthenticationService.swift`)

### Support Files
- **View Models**: `[Feature]ViewModel.swift`
- **Repository**: `[Entity]Repository.swift`
- **Utilities**: `[Purpose]Utilities.swift` or `[Domain]Helpers.swift`

## Import Organization Standards

### Standard Import Order
```swift
// 1. System frameworks (alphabetical)
import Foundation
import SwiftUI
import UIKit

// 2. External frameworks (alphabetical)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

// 3. Internal modules (if any)
// import InternalModule

// 4. Local imports (relative to current module)
// [No explicit imports needed for same-module files]
```

### Firebase Integration Pattern
```swift
// Standard Firebase imports for data-related files
import FirebaseFirestore
import FirebaseFirestoreSwift

// Authentication-related files
import FirebaseAuth

// App initialization
import FirebaseCore
```

## Key Architectural Principles

### Single Responsibility Principle
- **File Size Limit**: Target 250 lines, maximum 300 lines per file
- **Component Scope**: Each component has one clear responsibility
- **Service Boundaries**: Services handle specific domains or external integrations
- **View Separation**: Complex views broken into smaller, focused sub-views

### Component Composition
```swift
// Example: Complex view composed of focused components
ProjectDetailView
├── ProjectHeaderComponent
├── ProjectStatsComponent
├── TaskListComponent
│   └── TaskRowComponent
└── ProjectActionsComponent
```

### Repository Pattern Implementation
```
Repository Layer:
├── Protocol Definitions (interfaces)
├── Firebase Implementations (concrete classes)
├── Local Cache Implementations (offline support)
└── Mock Implementations (testing)
```

### MVVM with Services
```
View → ViewModel → Service → Repository → Firebase
  ↑                   ↓
  └── UI Updates ←── State Changes
```

## Directory-Specific Patterns

### Components Directory
**Purpose**: Reusable UI components and system utilities
```
Components/
├── UI Elements/                    # Basic UI components (buttons, inputs, cards)
├── System Components/              # Infrastructure (accessibility, performance)
├── Business Components/            # Domain-specific reusable components
└── Layout Components/              # Layout and navigation helpers
```

**Organization Rules**:
- Atomic components in root level
- Related components grouped in subdirectories
- System components separate from business components
- Performance and accessibility components clearly identified

### Views Directory
**Purpose**: Screen-level SwiftUI views and view hierarchies
```
Views/
├── Main Screens/                   # Primary application screens
├── Modal Sheets/                   # Presented views and sheets
├── Components/                     # View-specific components (not reusable)
└── Supporting Views/               # Helper and utility views
```

**Organization Rules**:
- One view per file maximum
- Related views can share a file if they're small and tightly coupled
- Screen-specific components in Views/Components/ subdirectory
- Modal and sheet views clearly distinguished

### Services Directory
**Purpose**: Business logic, external integrations, and application services
```
Services/
├── Authentication/                 # Auth-related services
├── Data Management/                # Data persistence and sync
├── AI Integration/                 # AI-powered features
├── Family Management/              # Family-specific business logic
├── Project Management/             # Project and task management
└── System Services/                # App lifecycle and system integration
```

**Organization Rules**:
- Services grouped by business domain
- Clear separation between external integrations and business logic
- Protocol-first design for testability
- Dependency injection patterns throughout

### Models Directory
**Purpose**: Data models, entities, and related business logic
```
Models/
├── Core Entities/                  # Primary business objects (Project, Task, Family)
├── Supporting Models/              # Helper and utility models
├── Extensions/                     # Model extensions and computed properties
└── Relationships/                  # Model relationship definitions
```

**Organization Rules**:
- One primary model per file
- Extensions in separate files when substantial
- Relationship definitions centralized
- Firebase Codable conformance clearly documented

## Testing Structure

### iOS Testing (`iOS/shigodekiTests/`)
```
shigodekiTests/
├── Unit Tests/                     # Component and service unit tests
├── Integration Tests/              # Multi-component integration tests
├── UI Tests/                       # SwiftUI and user interaction tests
└── Mock Objects/                   # Test doubles and mock implementations
```

### Firebase Testing (`iOS/test/`)
```
test/
├── family-access.test.js          # Family permission testing
├── security.test.js               # Security rule validation
├── realistic-security.test.js     # Real-world security scenarios
└── invite-security.test.js        # Invitation system testing
```

## Configuration and Build Structure

### Firebase Configuration
```
iOS/Firebase/
├── Config/
│   ├── GoogleService-Info-Dev.plist    # Development environment
│   └── GoogleService-Info-Prod.plist   # Production environment
├── Scripts/
│   └── copy-config.sh                   # Automated config switching
└── README.md                            # Setup instructions
```

### Xcode Project Organization
```
shigodeki.xcodeproj/
├── project.pbxproj                 # Project configuration
├── project.xcworkspace/            # Workspace settings
├── xcuserdata/                     # User-specific settings (gitignored)
└── xcshareddata/                   # Shared project data
```

## Code Quality and Standards

### File Size Guidelines
- **Target**: 250 lines per file for optimal readability
- **Maximum**: 300 lines per file (enforcement via pull request template)
- **Refactoring Trigger**: Files approaching 300 lines must be split
- **Exception Process**: Temporary exceptions require documented repayment plan

### Naming Standards
- **Classes/Structs**: PascalCase (`ProjectManager`, `TaskRowView`)
- **Variables/Functions**: camelCase (`projectId`, `createTask()`)
- **Constants**: camelCase with descriptive names (`maxTaskNameLength`)
- **Enums**: PascalCase with camelCase cases (`ProjectOwnerType.individual`)

### Documentation Standards
- **Public APIs**: Comprehensive documentation required
- **Complex Logic**: Inline comments for non-obvious code
- **Architecture Decisions**: Documented in steering documents
- **Breaking Changes**: Clear migration guides in pull requests

## Import Dependencies and Module Structure

### Internal Module Dependencies
```
Views → ViewModels → Services → Repository
  ↓         ↓           ↓          ↓
Components → Models → External APIs
```

### External Framework Usage
- **Firebase**: Core data and authentication services
- **SwiftUI**: Primary UI framework
- **Foundation**: System services and utilities
- **UIKit**: Bridge for UIKit interoperability when needed

### Dependency Injection Pattern
```swift
// Protocol-first service definitions
protocol ProjectService {
    func createProject(_ project: Project) async throws
}

// Concrete implementations
class FirebaseProjectService: ProjectService {
    // Implementation
}

// Dependency injection in views
struct ProjectListView: View {
    @ObservedObject private var projectService: ProjectService
    
    init(projectService: ProjectService = FirebaseProjectService()) {
        self.projectService = projectService
    }
}
```

This project structure supports the complex requirements of family-oriented task management while maintaining clear separation of concerns, testability, and scalability. The organization facilitates both individual development and team collaboration while ensuring code quality and maintainability standards.