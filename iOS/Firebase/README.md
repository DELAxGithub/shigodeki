# Firebase Configuration Setup

## Overview
This project uses dual Firebase environments for safe development and production deployments.

## Environment Configuration

### Development Environment
- **Project ID**: `shigodeki-dev`
- **Bundle ID**: `com.hiroshikodera.shigodeki.dev`
- **Config File**: `Firebase/Config/GoogleService-Info-Dev.plist`

### Production Environment
- **Project ID**: `shigodeki-prod` 
- **Bundle ID**: `com.hiroshikodera.shigodeki`
- **Config File**: `Firebase/Config/GoogleService-Info-Prod.plist`

## Xcode Integration

### 1. Add Build Phase Script
In your Xcode project, add a **Run Script** phase in **Build Phases**:

```bash
${SRCROOT}/Firebase/Scripts/copy-config.sh
```

### 2. Firebase SDK Integration
Add Firebase SDK via **File > Add Packages...**:
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Required libraries: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`

### 3. Initialize Firebase
In your `AppDelegate` or main App file:

```swift
import FirebaseCore

// In application(_:didFinishLaunchingWithOptions:) or App init
FirebaseApp.configure()
```

## How It Works
- **Debug builds** automatically use development Firebase project
- **Release builds** automatically use production Firebase project
- No manual configuration switching required

## Firebase Console Links
- [Development Console](https://console.firebase.google.com/project/shigodeki-dev/overview)
- [Production Console](https://console.firebase.google.com/project/shigodeki-prod/overview)