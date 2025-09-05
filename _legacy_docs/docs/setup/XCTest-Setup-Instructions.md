# XCTest Setup Instructions for iOS (2024/2025)

Complete guide for setting up modern XCTest infrastructure with ViewInspector, Firebase testing, and memory leak detection.

## 📋 Overview

This setup provides comprehensive testing capabilities including:
- ✅ XCTest unit and integration testing
- ✅ ViewInspector for SwiftUI view testing
- ✅ Firebase Local Emulator Suite integration
- ✅ Advanced memory leak detection
- ✅ Async/await testing patterns
- ✅ Performance testing framework

## 🚀 Quick Setup

### Step 1: Add Test Target to Xcode Project

1. Open your Xcode project (`shigodeki.xcodeproj`)
2. In Xcode, go to **File → New → Target**
3. Choose **Unit Testing Bundle** for iOS
4. Set the following:
   - Product Name: `shigodekiTests`
   - Team: Your development team
   - Bundle Identifier: `com.hiroshikodera.shigodeki.tests`
   - Project: `shigodeki`
   - Target to be Tested: `shigodeki`

### Step 2: Add Package Dependencies

1. In Xcode, go to **File → Add Package Dependencies**
2. Add the following packages to your **test target only**:

```
https://github.com/nalexn/ViewInspector
```

**Important**: Make sure to add ViewInspector only to your test target, not the main app target.

### Step 3: Copy Test Files

All test files have been created in the `shigodekiTests/` directory:

```
shigodekiTests/
├── XCTestCase+MemoryLeak.swift          # Memory leak testing framework
├── FirebaseTestingSetup.swift           # Firebase emulator setup
├── SwiftUITestingSetup.swift            # ViewInspector setup and utilities
├── Unit/
│   └── ContentViewTests.swift           # SwiftUI view tests
├── Integration/
│   └── FirebaseIntegrationTests.swift   # Firebase integration tests
└── Memory/
    └── MemoryLeakTests.swift            # Comprehensive memory leak tests
```

### Step 4: Configure Test Scheme

1. In Xcode, click on your scheme name → **Edit Scheme**
2. Select **Test** from the sidebar
3. Under **Environment Variables**, add:
   - `UNIT_TESTING`: `true`
   - `USE_FIREBASE_EMULATOR`: `true`
   - `FIREBASE_EMULATOR_HOST`: `localhost`

### Step 5: Set up Firebase Local Emulator Suite

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
firebase login
```

2. Start the Firebase emulators:
```bash
cd /path/to/your/project
firebase emulators:start
```

The emulators will start on:
- Auth: http://localhost:9099
- Firestore: http://localhost:8080
- Emulator UI: http://localhost:4000

## 🧪 Running Tests

### Run All Tests
```bash
# Command line
xcodebuild test -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode: Cmd+U
```

### Run Specific Test Suites
```bash
# Unit tests only
xcodebuild test -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:shigodekiTests/ContentViewTests

# Memory leak tests only  
xcodebuild test -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:shigodekiTests/MemoryLeakTests

# Firebase integration tests
xcodebuild test -scheme shigodeki -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:shigodekiTests/FirebaseIntegrationTests
```

## 📱 Test Categories

### 1. Unit Tests (`Unit/`)
- SwiftUI view rendering tests
- State management validation
- User interaction simulation
- ViewInspector integration

Example:
```swift
func testContentViewRendersWithoutErrors() throws {
    let view = ContentView()
        .environmentObject(mockAuthManager)
    
    try assertViewCanBeInspected(view)
}
```

### 2. Integration Tests (`Integration/`)
- Firebase authentication flows
- Firestore data operations
- Real-time listener testing
- Security rules validation

Example:
```swift
func testUserRegistration() async throws {
    let user = try await createTestUser(email: "test@example.com", password: "password")
    XCTAssertNotNil(user.uid)
}
```

### 3. Memory Leak Tests (`Memory/`)
- View controller lifecycle testing
- Combine publisher leak detection
- Async/await memory validation
- SwiftUI view memory testing

Example:
```swift
func testAuthenticationManagerMemoryLeak() {
    weak var weakManager: AuthenticationManager?
    
    autoreleasepool {
        let manager = AuthenticationManager()
        weakManager = manager
        // Perform operations...
    }
    
    XCTAssertNil(weakManager, "Manager should be deallocated")
}
```

## 🔧 Advanced Configuration

### Custom Test Data

Use `FirebaseTestDataFactory` to create consistent test data:

```swift
let userData = FirebaseTestDataFactory.createTestUser(id: "test-user")
let projectData = FirebaseTestDataFactory.createTestProject(familyID: "family-1")
```

### Memory Tracking

Use the memory leak extension for automatic tracking:

```swift
override func setUp() {
    super.setUp()
    let manager = MyManager()
    trackForMemoryLeak(instance: manager)
}
```

### ViewInspector Custom Extensions

Extend your views for testability:

```swift
extension MyCustomView: Inspectable { }
```

## 🚨 Troubleshooting

### Common Issues

1. **ViewInspector Compilation Errors**
   - Ensure ViewInspector is added only to test target
   - Check that views conform to `Inspectable` protocol

2. **Firebase Emulator Connection Issues**
   - Verify emulators are running: `firebase emulators:list`
   - Check environment variables are set correctly
   - Ensure `firebase.json` is properly configured

3. **Memory Leak False Positives**
   - Check for async operations completing after test ends
   - Verify all Combine subscriptions are properly cancelled
   - Use `autoreleasepool` for proper memory management

4. **Test Timeouts**
   - Increase timeout for async operations
   - Use `await fulfillment(of: [expectation], timeout: 10.0)`

### Performance Optimization

- Use `measure { }` blocks for performance testing
- Track memory usage with `trackMemoryUsage(maxMemoryMB: 25.0)`
- Run tests in parallel when possible

## 📚 Best Practices

### Test Organization
- Group related tests in test cases
- Use descriptive test method names
- Add documentation for complex test scenarios

### Data Management
- Always reset Firebase state between tests
- Use mock objects for external dependencies
- Clear all state in `tearDown()` methods

### Async Testing
- Use async/await patterns for modern Swift code
- Handle async operations with proper expectations
- Test both success and failure scenarios

### Memory Testing
- Test all view controllers and managers
- Verify Combine publishers don't create retain cycles
- Use weak references in test code appropriately

## 🔍 Debugging Tests

### Xcode Test Navigator
- Use Test Navigator (Cmd+6) to run individual tests
- View test results and failures inline
- Access test logs and crash reports

### Firebase Emulator UI
- Open http://localhost:4000 for emulator dashboard
- View authentication users and Firestore data
- Monitor real-time operations during tests

### Console Logging
Tests include comprehensive logging:
- `🔥 Firebase configured for testing`
- `🧹 Firebase state reset for next test`
- `⚠️ Error clearing collection`

## 🎯 Next Steps

1. **Customize Test Data**: Modify `FirebaseTestDataFactory` for your specific models
2. **Add UI Tests**: Consider adding XCUITest for end-to-end testing
3. **CI/CD Integration**: Set up automated testing in your build pipeline
4. **Code Coverage**: Enable code coverage reporting in Xcode scheme settings
5. **Test Documentation**: Document your specific test scenarios and expected behaviors

## 📖 Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [ViewInspector GitHub](https://github.com/nalexn/ViewInspector)
- [Firebase Local Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Swift Testing Best Practices](https://developer.apple.com/videos/play/wwdc2021/10195/)

---

**Created**: 2025 | **Updated**: Latest iOS testing practices
**Compatibility**: iOS 16+, Xcode 15+, Swift 5.9+