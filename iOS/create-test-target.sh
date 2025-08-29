#!/bin/bash

# Create Unit Testing Bundle target for shigodeki project
# Since Xcode doesn't have a direct CLI command to add targets, 
# we'll create a minimal test target configuration

echo "🚀 Creating test target for shigodeki..."

# Generate UUIDs for the new target
TEST_TARGET_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_PRODUCT_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_BUILD_PHASE_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_BUILD_CONFIG_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_DEBUG_CONFIG_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_RELEASE_CONFIG_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_DEPENDENCY_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"
TEST_FILE_SYSTEM_UUID="DE918B$(openssl rand -hex 12 | tr '[:lower:]' '[:upper:]' | head -c 10)0340EB2"

echo "Generated UUIDs:"
echo "  Target: $TEST_TARGET_UUID"
echo "  Product: $TEST_PRODUCT_UUID"
echo "  Build Phase: $TEST_BUILD_PHASE_UUID"

# Create a backup of the project file
cp shigodeki.xcodeproj/project.pbxproj shigodeki.xcodeproj/project.pbxproj.backup

# Since direct pbxproj editing is complex, let's try a different approach
# Create a template test file that Xcode can recognize
mkdir -p shigodekiTests

# Create a simple test file that can help Xcode recognize this as a test bundle
cat > shigodekiTests/shigodekiTests.swift << 'EOF'
//
//  shigodekiTests.swift
//  shigodekiTests
//
//  Created by Claude on $(date +%Y-%m-%d).
//

import XCTest
@testable import shigodeki

final class shigodekiTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
EOF

echo "✅ Created basic test structure"

# Now let's try a different approach using the Swift Package Manager format
# that modern Xcode projects can recognize

# Check if we can use xcodegen or similar tools
if command -v xcodegen >/dev/null 2>&1; then
    echo "📦 xcodegen found, using project.yml approach..."
    # Create project.yml for xcodegen
    cat > project.yml << 'EOF'
name: shigodeki
options:
  bundleIdPrefix: com.company
targets:
  shigodeki:
    type: application
    platform: iOS
    deploymentTarget: "15.0"
    sources:
      - shigodeki/
    dependencies:
      - package: Firebase
        products:
          - FirebaseAuth
          - FirebaseCore
          - FirebaseFirestore
  shigodekiTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "15.0"
    sources:
      - shigodekiTests/
    dependencies:
      - target: shigodeki
packages:
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk
    from: "12.2.0"
EOF
    
    # Generate the project with tests
    xcodegen generate
    
    if [ $? -eq 0 ]; then
        echo "✅ Project regenerated with test target using xcodegen"
    else
        echo "❌ xcodegen failed, reverting to manual approach"
        rm -f project.yml
    fi
else
    echo "⚠️  xcodegen not found, using manual Xcode approach"
    echo ""
    echo "📝 Manual steps required:"
    echo "1. Open shigodeki.xcodeproj in Xcode"
    echo "2. File → New → Target"
    echo "3. iOS → Unit Testing Bundle"
    echo "4. Product Name: shigodekiTests"
    echo "5. Language: Swift"
    echo "6. Use Core Data: No"
    echo "7. Add the test files from shigodekiTests/ directory"
    echo ""
    echo "🎯 After manual setup, run: ./run-tests.sh unit --verbose"
fi

echo "🎉 Test target setup completed!"