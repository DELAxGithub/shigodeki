#!/usr/bin/env python3
"""
Add Unit Testing Bundle target to shigodeki Xcode project
This script directly modifies the project.pbxproj file to add a test target
"""

import re
import uuid
import os
import sys
from pathlib import Path


def generate_xcode_uuid():
    """Generate 24-character uppercase hex UUID for Xcode"""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]


def add_test_target_to_project():
    """Add test target to Xcode project file"""
    
    project_file = "shigodeki.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_file):
        print(f"❌ Error: {project_file} not found")
        return False
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    print("🔥 [SCORCHED EARTH] Adding test target to Xcode project...")
    
    # Generate UUIDs for test target components
    test_target_uuid = generate_xcode_uuid()
    test_framework_uuid = generate_xcode_uuid() 
    test_sources_uuid = generate_xcode_uuid()
    test_resources_uuid = generate_xcode_uuid()
    test_product_uuid = generate_xcode_uuid()
    test_group_uuid = generate_xcode_uuid()
    test_build_config_list_uuid = generate_xcode_uuid()
    test_debug_config_uuid = generate_xcode_uuid()
    test_release_config_uuid = generate_xcode_uuid()
    test_dependency_uuid = generate_xcode_uuid()
    test_target_dependency_uuid = generate_xcode_uuid()
    
    # Add test product to file references
    file_ref_pattern = r'(\/\* End PBXFileReference section \*\/)'
    test_product_ref = f'\t\t{test_product_uuid} /* shigodekiTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = shigodekiTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};\n/* End PBXFileReference section */'
    content = re.sub(file_ref_pattern, test_product_ref, content)
    
    # Add test target to frameworks build phase
    frameworks_pattern = r'(\/\* End PBXFrameworksBuildPhase section \*\/)'
    test_frameworks = f'''\t\t{test_framework_uuid} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */'''
    content = re.sub(frameworks_pattern, test_frameworks, content)
    
    # Add test group to Products group
    products_pattern = r'(\t\t\tchildren = \(\s*\t\t\t\t[A-F0-9]{24} \/\* shigodeki\.app \*\/,\s*\t\t\t\);)'
    test_product_in_group = f'''\t\t\tchildren = (
\t\t\t\tDE918B062E5FC87300340EB2 /* shigodeki.app */,
\t\t\t\t{test_product_uuid} /* shigodekiTests.xctest */,
\t\t\t);'''
    content = re.sub(products_pattern, test_product_in_group, content)
    
    # Add test sources group
    root_group_pattern = r'(\t\t\tchildren = \(\s*\t\t\t\tDE918B082E5FC87300340EB2 \/\* shigodeki \*\/,\s*\t\t\t\tDE5F1BE62E5FD31100A91735 \/\* Frameworks \*\/,\s*\t\t\t\tDE918B072E5FC87300340EB2 \/\* Products \*\/,\s*\t\t\t\);)'
    test_group_in_root = f'''\t\t\tchildren = (
\t\t\t\tDE918B082E5FC87300340EB2 /* shigodeki */,
\t\t\t\t{test_group_uuid} /* shigodekiTests */,
\t\t\t\tDE5F1BE62E5FD31100A91735 /* Frameworks */,
\t\t\t\tDE918B072E5FC87300340EB2 /* Products */,
\t\t\t);'''
    content = re.sub(root_group_pattern, test_group_in_root, content)
    
    # Add test group definition
    group_pattern = r'(\/\* End PBXGroup section \*\/)'
    test_group_def = f'''\t\t{test_group_uuid} /* shigodekiTests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t);
\t\t\tpath = shigodekiTests;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */'''
    content = re.sub(group_pattern, test_group_def, content)
    
    # Add test target definition
    target_pattern = r'(\/\* End PBXNativeTarget section \*\/)'
    test_target_def = f'''\t\t{test_target_uuid} /* shigodekiTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {test_build_config_list_uuid} /* Build configuration list for PBXNativeTarget "shigodekiTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{test_sources_uuid} /* Sources */,
\t\t\t\t{test_framework_uuid} /* Frameworks */,
\t\t\t\t{test_resources_uuid} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{test_dependency_uuid} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = shigodekiTests;
\t\t\tproductName = shigodekiTests;
\t\t\tproductReference = {test_product_uuid} /* shigodekiTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};
/* End PBXNativeTarget section */'''
    content = re.sub(target_pattern, test_target_def, content)
    
    # Add test target to project targets
    project_targets_pattern = r'(\t\t\ttargets = \(\s*\t\t\t\tDE918B052E5FC87300340EB2 \/\* shigodeki \*\/,\s*\t\t\t\);)'
    test_in_targets = f'''\t\t\ttargets = (
\t\t\t\tDE918B052E5FC87300340EB2 /* shigodeki */,
\t\t\t\t{test_target_uuid} /* shigodekiTests */,
\t\t\t);'''
    content = re.sub(project_targets_pattern, test_in_targets, content)
    
    # Add test target attributes
    target_attrs_pattern = r'(\t\t\t\tDE918B052E5FC87300340EB2 = \{\s*\t\t\t\t\tCreatedOnToolsVersion = 16\.4;\s*\t\t\t\t\};)'
    test_target_attrs = f'''\t\t\t\tDE918B052E5FC87300340EB2 = {{
\t\t\t\t\tCreatedOnToolsVersion = 16.4;
\t\t\t\t}};
\t\t\t\t{test_target_uuid} = {{
\t\t\t\t\tCreatedOnToolsVersion = 16.4;
\t\t\t\t\tTestTargetID = DE918B052E5FC87300340EB2;
\t\t\t\t}};'''
    content = re.sub(target_attrs_pattern, test_target_attrs, content)
    
    # Add resources build phase
    resources_pattern = r'(\/\* End PBXResourcesBuildPhase section \*\/)'
    test_resources = f'''\t\t{test_resources_uuid} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */'''
    content = re.sub(resources_pattern, test_resources, content)
    
    # Add sources build phase
    sources_pattern = r'(\/\* End PBXSourcesBuildPhase section \*\/)'
    test_sources = f'''\t\t{test_sources_uuid} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */'''
    content = re.sub(sources_pattern, test_sources, content)
    
    # Add target dependency
    if "/* Begin PBXTargetDependency section */" not in content:
        # Add the section header before build configurations
        build_config_pattern = r'(\/\* Begin XCBuildConfiguration section \*\/)'
        target_dep_section = f'''/* Begin PBXTargetDependency section */
\t\t{test_dependency_uuid} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = DE918B052E5FC87300340EB2 /* shigodeki */;
\t\t\ttargetProxy = {test_target_dependency_uuid} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */'''
        content = re.sub(build_config_pattern, target_dep_section, content)
        
        # Add container item proxy section
        target_dep_pattern = r'(\/\* Begin PBXTargetDependency section \*\/)'
        container_proxy_section = f'''/* Begin PBXContainerItemProxy section */
\t\t{test_target_dependency_uuid} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = DE918AFE2E5FC87300340EB2 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = DE918B052E5FC87300340EB2;
\t\t\tremoteInfo = shigodeki;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXTargetDependency section */'''
        content = re.sub(target_dep_pattern, container_proxy_section, content)
    
    # Add build configurations for test target
    build_config_section_pattern = r'(\/\* End XCBuildConfiguration section \*\/)'
    test_build_configs = f'''\t\t{test_debug_config_uuid} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 4;
\t\t\t\tDEVELOPMENT_TEAM = Z88477N5ZU;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIOSPLATFORM_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.hiroshikodera.shigodeki.shigodekiTests";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/shigodeki.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/shigodeki";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{test_release_config_uuid} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 4;
\t\t\t\tDEVELOPMENT_TEAM = Z88477N5ZU;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIOSPLATFORM_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.hiroshikodera.shigodeki.shigodekiTests";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/shigodeki.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/shigodeki";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */'''
    content = re.sub(build_config_section_pattern, test_build_configs, content)
    
    # Add build configuration list for test target
    build_config_list_pattern = r'(\/\* End XCConfigurationList section \*\/)'
    test_build_config_list = f'''\t\t{test_build_config_list_uuid} /* Build configuration list for PBXNativeTarget "shigodekiTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{test_debug_config_uuid} /* Debug */,
\t\t\t\t{test_release_config_uuid} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */'''
    content = re.sub(build_config_list_pattern, test_build_config_list, content)
    
    # Write the modified content back
    with open(project_file, 'w') as f:
        f.write(content)
    
    print(f"✅ Successfully added test target to {project_file}")
    return True


def main():
    print("🔥 [SCORCHED EARTH] Phase A: Adding test target to Xcode project")
    
    if add_test_target_to_project():
        print("✅ [SMOKE SIGNAL] Test target successfully added to Xcode project")
        print("🎯 Next steps:")
        print("   1. Run: xcodebuild test -project shigodeki.xcodeproj -scheme shigodeki")
        print("   2. Verify that testInfrastructure_SmokeSignal_MustPass shows GREEN")
        print("   3. The rebuilding of our testing fortress begins!")
    else:
        print("❌ Failed to add test target")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())