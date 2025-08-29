#!/usr/bin/env python3
"""
Setup script to add Unit Testing Bundle target to shigodeki Xcode project
"""

import subprocess
import sys
import os
import uuid
from pathlib import Path

def run_command(cmd, cwd=None):
    """Run shell command and return result"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def generate_uuid():
    """Generate a UUID for Xcode project entries"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def main():
    print("🚀 Setting up Unit Testing Bundle target for shigodeki...")
    
    # Check if we're in the right directory
    if not os.path.exists('shigodeki.xcodeproj'):
        print("❌ Error: shigodeki.xcodeproj not found. Please run from iOS project directory.")
        sys.exit(1)
    
    # Create Info.plist for test target
    test_info_plist = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>"""
    
    # Create Info.plist in shigodekiTests directory
    info_plist_path = Path("shigodekiTests/Info.plist")
    info_plist_path.parent.mkdir(exist_ok=True)
    
    with open(info_plist_path, 'w') as f:
        f.write(test_info_plist)
    print("✅ Created Info.plist for test target")
    
    # Use xcodebuild to add test target (we'll use a template approach)
    print("📱 Adding Unit Testing Bundle target...")
    
    # First, let's try using xcodebuild to create a scheme that includes tests
    success, stdout, stderr = run_command(
        f"xcodebuild -create-xcframework -help", 
        cwd="."
    )
    
    if success:
        print("✅ xcodebuild is available")
    
    # For modern Xcode projects, we can try to manually edit the scheme
    schemes_dir = Path("shigodeki.xcodeproj/xcshareddata/xcschemes")
    schemes_dir.mkdir(parents=True, exist_ok=True)
    
    # Create a scheme that includes tests
    scheme_content = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      runPostActionsOnFailure = "NO">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "DE918B052E5FC87300340EB2"
               BuildableName = "shigodeki.app"
               BlueprintName = "shigodeki"
               ReferencedContainer = "container:shigodeki.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      enableAddressSanitizer = "NO"
      enableASanStackUseAfterReturn = "NO"
      enableUBSanitizer = "NO"
      enableThreadSanitizer = "NO">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES"
            testExecutionOrdering = "random">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "TESTBUNDLEID"
               BuildableName = "shigodekiTests.xctest"
               BlueprintName = "shigodekiTests"
               ReferencedContainer = "container:shigodeki.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "DE918B052E5FC87300340EB2"
            BuildableName = "shigodeki.app"
            BlueprintName = "shigodeki"
            ReferencedContainer = "container:shigodeki.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>"""
    
    # Write scheme file
    scheme_file = schemes_dir / "shigodeki.xcscheme"
    with open(scheme_file, 'w') as f:
        f.write(scheme_content)
    print(f"✅ Created scheme file: {scheme_file}")
    
    print("\n🎯 Setup completed! Next steps:")
    print("1. Open shigodeki.xcodeproj in Xcode")
    print("2. File → New → Target → Unit Testing Bundle")
    print("3. Name: shigodekiTests")
    print("4. Add the test files from shigodekiTests/ directory to the new target")
    print("5. Build Settings → Test Host: $(BUILT_PRODUCTS_DIR)/shigodeki.app/shigodeki")
    print("6. Try running: ./run-tests.sh unit")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())