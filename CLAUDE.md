# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

シゴデキ (Shigodeki) is an iOS application project using Firebase as the backend. This is currently in the initial setup phase with architecture planning completed but implementation not yet started.

## Project Architecture

### Environment Strategy
- **Dual Environment Setup**: The project uses separate Firebase projects for development and production
  - Development: `shigodeki-dev` 
  - Production: `shigodeki-prod`
- **Bundle ID Separation**: 
  - Production: `com.company.shigodeki`
  - Development: `com.company.shigodeki.dev`

### Firebase Configuration
- **Authentication Methods**: Sign in with Apple (mandatory), with optional Email/Password and Google authentication
- **Database**: Firestore with family-shared data model
- **Data Structure**:
  ```
  families/{familyId}/
  ├── taskLists/{listId}/
  │   └── tasks/{taskId}
  └── users/{userId}
  ```

### Security Model
- Users can only access their own user data
- Family data is restricted to family members only
- Firestore security rules enforce these access patterns

### iOS Project Structure
- Configuration files stored in `Firebase/Config/`:
  - `GoogleService-Info-Dev.plist` (development)
  - `GoogleService-Info-Prod.plist` (production)
- Build script automatically copies appropriate config file based on build configuration
- Debug builds connect to development Firebase project
- Release builds connect to production Firebase project

## Development Workflow

### Initial Setup Commands
```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Create Firebase projects
firebase projects:create shigodeki-dev --display-name "シゴデキ (Dev)"
firebase projects:create shigodeki-prod --display-name "シゴデキ (Prod)"

# Register iOS apps (run interactively for each environment)
firebase apps:create
```

### Build Configuration
- The project uses Xcode build phases with run scripts to handle environment-specific configuration
- No manual file switching required - build configuration automatically selects appropriate Firebase config

## Key Implementation Notes

- Start development with user registration/login functionality
- Verify Firestore connectivity by testing data writes to the `users` collection
- Firebase SDK includes: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`
- Initialization code: `FirebaseApp.configure()` in AppDelegate or main App file