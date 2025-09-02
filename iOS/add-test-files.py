#!/usr/bin/env python3
"""
Add test files to shigodeki Xcode project test target
"""

import re
import uuid
import os
import sys
from pathlib import Path


def generate_xcode_uuid():
    """Generate 24-character uppercase hex UUID for Xcode"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]


def add_test_files_to_project():
    """Add test files to Xcode project test target"""
    
    project_file = "shigodeki.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_file):
        print(f"❌ Error: {project_file} not found")
        return False
    
    # Find test files
    test_files = []
    if os.path.exists("shigodekiTests"):
        for file in os.listdir("shigodekiTests"):
            if file.endswith(".swift"):
                test_files.append(file)
    
    if not test_files:
        print("❌ No test files found in shigodekiTests directory")
        return False
    
    print(f"🔥 [SCORCHED EARTH] Adding {len(test_files)} test files to project...")
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for test files
    file_uuids = {}
    build_file_uuids = {}
    
    for test_file in test_files:
        file_uuids[test_file] = generate_xcode_uuid()
        build_file_uuids[test_file] = generate_xcode_uuid()
    
    # Add file references
    file_ref_pattern = r'(\t\t21F4A092A50D43B286A73DF1 \/\* shigodekiTests\.xctest \*\/ = \{[^}]+\};\n\/\* End PBXFileReference section \*\/)'
    
    test_file_refs = []
    for test_file in test_files:
        test_file_refs.append(f'\t\t{file_uuids[test_file]} /* {test_file} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {test_file}; sourceTree = "<group>"; }};')
    
    new_file_refs = '\t\t21F4A092A50D43B286A73DF1 /* shigodekiTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = shigodekiTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };\n' + '\n'.join(test_file_refs) + '\n/* End PBXFileReference section */'
    
    content = re.sub(file_ref_pattern, new_file_refs, content)
    
    # Add build files
    build_file_pattern = r'(\/\* End PBXBuildFile section \*\/)'
    
    test_build_files = []
    for test_file in test_files:
        test_build_files.append(f'\t\t{build_file_uuids[test_file]} /* {test_file} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuids[test_file]} /* {test_file} */; }};')
    
    new_build_files = '\n'.join(test_build_files) + '\n/* End PBXBuildFile section */'
    content = re.sub(build_file_pattern, new_build_files, content)
    
    # Add files to test group
    test_group_pattern = r'(\t\t0C71054B47214D708B37135E \/\* shigodekiTests \*\/ = \{\s*isa = PBXGroup;\s*children = \(\s*\);\s*path = shigodekiTests;\s*sourceTree = "<group>";\s*\};)'
    
    test_group_children = []
    for test_file in test_files:
        test_group_children.append(f'\t\t\t\t{file_uuids[test_file]} /* {test_file} */,')
    
    new_test_group = f'''\t\t0C71054B47214D708B37135E /* shigodekiTests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(test_group_children)}
\t\t\t);
\t\t\tpath = shigodekiTests;
\t\t\tsourceTree = "<group>";
\t\t}};'''
    
    content = re.sub(test_group_pattern, new_test_group, content)
    
    # Add files to test target sources build phase
    test_sources_pattern = r'(\t\tCF79BBC3C58E453C9D70D377 \/\* Sources \*\/ = \{\s*isa = PBXSourcesBuildPhase;\s*buildActionMask = 2147483647;\s*files = \(\s*\);\s*runOnlyForDeploymentPostprocessing = 0;\s*\};)'
    
    test_source_files = []
    for test_file in test_files:
        test_source_files.append(f'\t\t\t\t{build_file_uuids[test_file]} /* {test_file} in Sources */,')
    
    new_test_sources = f'''\t\tCF79BBC3C58E453C9D70D377 /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(test_source_files)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};'''
    
    content = re.sub(test_sources_pattern, new_test_sources, content)
    
    # Write the modified content back
    with open(project_file, 'w') as f:
        f.write(content)
    
    print(f"✅ Successfully added {len(test_files)} test files to {project_file}")
    return True


def main():
    print("🔥 [SCORCHED EARTH] Phase A: Adding test files to Xcode project")
    
    if add_test_files_to_project():
        print("✅ [SMOKE SIGNAL] Test files successfully added to Xcode project")
        print("🎯 Now ready to run smoke signal test!")
    else:
        print("❌ Failed to add test files")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())