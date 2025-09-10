# Technology Stack - シゴデキ (Shigodeki)

**Inclusion Mode**: Always (Loaded in every interaction)

## Architecture Overview

シゴデキ follows a modern iOS architecture with Firebase backend services, implementing a dual-environment strategy for safe development and production deployments. The application uses a component-based SwiftUI architecture with clear separation of concerns across presentation, business logic, and data layers.

### High-Level Architecture
```
iOS App (SwiftUI) → Firebase SDK → Firebase Services
├── Authentication (Firebase Auth)
├── Database (Firestore)
├── Real-time Sync
└── Security Rules
```

## Frontend Technology Stack

### iOS Application
- **Framework**: SwiftUI (Native iOS)
- **Language**: Swift 5.7+
- **Minimum iOS Version**: iOS 15.0+
- **Architecture Pattern**: MVVM with Repository Pattern
- **UI Components**: Custom component library with design system

### Key iOS Dependencies
```swift
// Core Firebase SDK
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// iOS System Frameworks
import SwiftUI
import UIKit
import Foundation
import CoreData
```

### UI/UX Technologies
- **Design System**: Custom ColorSystem and AnimationSystem
- **Accessibility**: Full VoiceOver support, Dynamic Type, accessibility focus management
- **Performance**: IntegratedPerformanceMonitor, lazy loading, memory optimization
- **Navigation**: Custom navigation with gesture support and breadcrumb tracking

## Backend Technology Stack

### Firebase Services
- **Authentication**: Firebase Auth with Sign in with Apple (primary), Email/Password, Google Sign-In
- **Database**: Cloud Firestore (NoSQL document database)
- **Security**: Firestore Security Rules with family-based access control
- **Real-time Sync**: Firebase real-time listeners with offline support

### Data Architecture
```
Cloud Firestore Collections:
├── users/{userId}
├── families/{familyId}
│   ├── projects/{projectId}
│   ├── tasks/{taskId}
│   └── taskLists/{listId}
├── invitations_unified/{code}
└── projectInvitations/{invitationId}
```

### Security Model
- **Authentication**: Multi-provider auth with Sign in with Apple priority
- **Authorization**: Family-scoped data access with granular permissions
- **Data Isolation**: Complete separation between family groups
- **Invitation Security**: Time-limited codes with validation rules

## Development Environment

### Dual Environment Strategy
```yaml
Development Environment:
  - Project ID: shigodeki-dev
  - Bundle ID: com.hiroshikodera.shigodeki.dev
  - Config: Firebase/Config/GoogleService-Info-Dev.plist
  - Build Configuration: Debug

Production Environment:
  - Project ID: shigodeki-prod
  - Bundle ID: com.hiroshikodera.shigodeki
  - Config: Firebase/Config/GoogleService-Info-Prod.plist
  - Build Configuration: Release
```

### Build System
- **Primary IDE**: Xcode 15.0+
- **Build Scripts**: Custom shell scripts for environment configuration
- **Configuration Management**: Automated config file switching based on build type
- **Firebase Integration**: Automatic project selection based on build configuration

### Testing Infrastructure
- **Unit Testing**: XCTest framework with comprehensive test coverage
- **Firebase Testing**: Node.js + Mocha for Firestore Security Rules testing
- **Integration Testing**: Firebase Rules Unit Testing framework
- **Performance Testing**: Built-in performance monitoring and reporting

## Common Development Commands

### Firebase Commands
```bash
# Firebase CLI installation and login
npm install -g firebase-tools
firebase login

# Environment setup
firebase use shigodeki-dev    # Switch to development
firebase use shigodeki-prod   # Switch to production

# Testing
npm run test                  # Run all tests
npm run test:family          # Run family access tests
npm run test:emulator        # Run tests with emulator
```

### Xcode Build Commands
```bash
# Build for development (uses dev Firebase config)
xcodebuild -scheme shigodeki -configuration Debug build

# Build for production (uses prod Firebase config)
xcodebuild -scheme shigodeki -configuration Release build

# Run tests
xcodebuild test -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Testing Commands
```bash
# Run Firebase security rules tests
cd iOS && npm test

# Run specific test suites
npm run test:family          # Family access tests
npm run test:security        # Security rule tests

# Firebase emulator for testing
firebase emulators:start --only firestore
firebase emulators:exec --only firestore 'npm run test:family'
```

## Environment Variables & Configuration

### Xcode Build Configuration
```bash
# Automatically set based on build configuration
FIREBASE_CONFIG_FILE=${SRCROOT}/Firebase/Config/GoogleService-Info-${CONFIGURATION}.plist
BUNDLE_IDENTIFIER=com.hiroshikodera.shigodeki${DEVELOPMENT_SUFFIX}
```

### Firebase Configuration Variables
```yaml
# Development Environment
PROJECT_ID: shigodeki-dev
API_KEY: [Auto-configured from GoogleService-Info-Dev.plist]
AUTH_DOMAIN: shigodeki-dev.firebaseapp.com

# Production Environment  
PROJECT_ID: shigodeki-prod
API_KEY: [Auto-configured from GoogleService-Info-Prod.plist]
AUTH_DOMAIN: shigodeki-prod.firebaseapp.com
```

### App Configuration
```swift
// Runtime configuration detection
let projectId = FirebaseApp.app()?.options.projectID
let isProduction = projectId?.contains("prod") ?? false
let isDevelopment = projectId?.contains("dev") ?? false
```

## Port Configuration & Services

### Standard Development Ports
```yaml
Firebase Emulator Suite:
  - Firestore: 8080
  - Authentication: 9099
  - Firebase UI: 4000

iOS Simulator:
  - Default simulator ports (managed by Xcode)
  - USB debugging via Xcode

Testing Services:
  - Mocha test runner: Various ports
  - Node.js testing: 3000-3999 range
```

### Network Configuration
- **Firebase Endpoints**: Auto-configured via GoogleService-Info.plist
- **Real-time Listeners**: WebSocket connections to Firestore
- **Offline Storage**: Local SQLite database via Firebase SDK

## Performance & Optimization

### iOS Performance Features
- **Lazy Loading**: Component-based lazy loading for large lists
- **Memory Management**: Proper Swift memory management with weak references
- **Battery Optimization**: Intelligent sync scheduling and background app refresh
- **Network Optimization**: Efficient Firestore queries with proper indexing

### Firebase Optimization
- **Query Optimization**: Compound indexes for complex queries
- **Offline First**: Local-first data access with background sync
- **Security Rules Optimization**: Efficient rule evaluation with minimal reads
- **Real-time Efficiency**: Selective real-time listeners to minimize data transfer

## Security Considerations

### Authentication Security
- **Primary Provider**: Sign in with Apple for maximum privacy
- **Fallback Methods**: Email/password and Google authentication
- **Token Management**: Automatic token refresh and secure storage
- **Session Management**: Proper session lifecycle and cleanup

### Data Security
- **Family Isolation**: Complete data separation between family groups
- **Permission Model**: Granular read/write permissions based on family membership
- **Invitation Security**: Time-limited invitation codes with automatic expiration
- **Audit Trail**: Comprehensive logging for security monitoring

### Development Security
- **Environment Separation**: Complete isolation between dev and prod environments
- **API Key Management**: Secure API key handling via plist configuration
- **Testing Isolation**: Dedicated test environment with synthetic data
- **Code Security**: No hardcoded secrets or sensitive data in source code

## Dependency Management

### iOS Dependencies
```swift
// Firebase SDK (via Swift Package Manager)
.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")

// Targets
.target(dependencies: [
    .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
    .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
    .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk")
])
```

### Testing Dependencies
```json
{
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.3",
    "mocha": "^10.2.0"
  }
}
```

### Version Management
- **iOS SDK**: Target latest stable Firebase iOS SDK
- **Node.js**: v18.0+ for testing infrastructure
- **Firebase CLI**: Latest stable version for project management
- **Xcode**: 15.0+ for modern SwiftUI features

## Integration Points

### Firebase Integration
- **Initialization**: FirebaseApp.configure() in AppDelegate
- **Authentication State**: Real-time auth state monitoring
- **Data Sync**: Background sync with conflict resolution
- **Offline Capability**: Automatic offline/online state management

### External Services
- **Apple Services**: Sign in with Apple, App Store Connect
- **Testing Services**: Firebase Test Lab (future consideration)
- **Analytics**: Firebase Analytics (future consideration)
- **Crash Reporting**: Firebase Crashlytics (future consideration)

## Development Workflow

### Environment Setup Process
1. Install Xcode 15.0+
2. Install Firebase CLI globally
3. Clone repository and navigate to iOS directory
4. Open shigodeki.xcodeproj in Xcode
5. Build scheme automatically selects appropriate Firebase configuration
6. Run tests to verify environment setup

### Deployment Process
1. **Development**: Automatic deployment to dev Firebase on debug builds
2. **Testing**: Comprehensive test suite validation before production
3. **Production**: Manual deployment to prod Firebase via release builds
4. **Monitoring**: Real-time monitoring of both environments

This technology stack provides a robust foundation for the シゴデキ application, ensuring scalability, security, and maintainability while supporting the complex requirements of family-oriented task management.