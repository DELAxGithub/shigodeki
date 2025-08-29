#!/bin/bash

#
# Automated Test Runner for Shigodeki iOS App
# Created by Claude on 2025-08-29
#
# Usage: ./run-tests.sh [test-type] [options]
# Test types: all, unit, integration, memory, ui
# Options: --verbose, --coverage, --device [device-name]
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="shigodeki"
SCHEME="shigodeki"
TEST_TARGET="shigodekiTests"
SIMULATOR="iPhone 16"
BUILD_DIR="./build"

# Flags
VERBOSE=false
COVERAGE=false
DEVICE=""
CLEAN_BUILD=false

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Parse command line arguments
TEST_TYPE="all"
while [[ $# -gt 0 ]]; do
    case $1 in
        all|unit|integration|memory|ui)
            TEST_TYPE="$1"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [test-type] [options]"
            echo "Test types: all, unit, integration, memory, ui"
            echo "Options:"
            echo "  --verbose     Enable verbose output"
            echo "  --coverage    Generate code coverage report"
            echo "  --device      Specify device/simulator name"
            echo "  --clean       Clean build before testing"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set device if not specified
if [[ -z "$DEVICE" ]]; then
    DEVICE="$SIMULATOR"
fi

print_header "Shigodeki iOS Test Runner"
print_info "Test Type: $TEST_TYPE"
print_info "Device: $DEVICE"
print_info "Coverage: $COVERAGE"
print_info "Verbose: $VERBOSE"

# Check if Xcode project exists
if [[ ! -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]]; then
    print_error "Xcode project not found: ${PROJECT_NAME}.xcodeproj"
    exit 1
fi

# Clean build if requested
if [[ "$CLEAN_BUILD" == true ]]; then
    print_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    xcodebuild clean \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME" \
        > /dev/null 2>&1 || true
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Build the project first
print_info "Building project..."
BUILD_CMD="xcodebuild build-for-testing \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme $SCHEME \
    -destination \"platform=iOS Simulator,name=$DEVICE\" \
    -derivedDataPath $BUILD_DIR"

if [[ "$VERBOSE" == false ]]; then
    BUILD_CMD="$BUILD_CMD > ${BUILD_DIR}/build.log 2>&1"
fi

if ! eval $BUILD_CMD; then
    print_error "Build failed"
    if [[ "$VERBOSE" == false ]]; then
        print_info "Build log:"
        tail -50 "${BUILD_DIR}/build.log"
    fi
    exit 1
fi

print_success "Build completed successfully"

# Function to run specific tests
run_tests() {
    local test_pattern="$1"
    local test_name="$2"
    
    print_info "Running $test_name tests..."
    
    # Base test command
    local test_cmd="xcodebuild test-without-building \
        -project ${PROJECT_NAME}.xcodeproj \
        -scheme $SCHEME \
        -destination \"platform=iOS Simulator,name=$DEVICE\" \
        -derivedDataPath $BUILD_DIR"
    
    # Add test pattern if specified
    if [[ -n "$test_pattern" ]]; then
        test_cmd="$test_cmd -only-testing:$test_pattern"
    fi
    
    # Add coverage if requested
    if [[ "$COVERAGE" == true ]]; then
        test_cmd="$test_cmd -enableCodeCoverage YES"
    fi
    
    # Set output handling
    if [[ "$VERBOSE" == false ]]; then
        test_cmd="$test_cmd > ${BUILD_DIR}/${test_name,,}_tests.log 2>&1"
    fi
    
    # Execute test command
    if eval $test_cmd; then
        print_success "$test_name tests passed"
        return 0
    else
        print_error "$test_name tests failed"
        if [[ "$VERBOSE" == false ]]; then
            print_info "Test log:"
            tail -50 "${BUILD_DIR}/${test_name,,}_tests.log"
        fi
        return 1
    fi
}

# Memory leak detection helper
check_memory_leaks() {
    print_info "Checking for memory leaks in test results..."
    
    local log_files=(${BUILD_DIR}/*_tests.log)
    local leak_found=false
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            if grep -q "memory leak\|retain count\|deallocated with non-zero" "$log_file"; then
                print_warning "Potential memory leak detected in $(basename $log_file)"
                grep -n "memory leak\|retain count\|deallocated with non-zero" "$log_file" | head -10
                leak_found=true
            fi
        fi
    done
    
    if [[ "$leak_found" == false ]]; then
        print_success "No memory leaks detected"
    fi
}

# Test execution
TEST_FAILURES=0

case $TEST_TYPE in
    "unit")
        run_tests "${TEST_TARGET}/Unit" "Unit" || ((TEST_FAILURES++))
        ;;
    "integration")
        run_tests "${TEST_TARGET}/Integration" "Integration" || ((TEST_FAILURES++))
        ;;
    "memory")
        run_tests "${TEST_TARGET}/Memory" "Memory" || ((TEST_FAILURES++))
        check_memory_leaks
        ;;
    "ui")
        run_tests "${TEST_TARGET}/UI" "UI" || ((TEST_FAILURES++))
        ;;
    "all")
        print_info "Running all test suites..."
        
        # Run each test suite
        run_tests "${TEST_TARGET}/Unit" "Unit" || ((TEST_FAILURES++))
        run_tests "${TEST_TARGET}/Integration" "Integration" || ((TEST_FAILURES++))
        run_tests "${TEST_TARGET}/Memory" "Memory" || ((TEST_FAILURES++))
        # run_tests "${TEST_TARGET}/UI" "UI" || ((TEST_FAILURES++))  # Uncomment when UI tests are added
        
        # Check for memory leaks across all tests
        check_memory_leaks
        ;;
    *)
        print_error "Unknown test type: $TEST_TYPE"
        exit 1
        ;;
esac

# Generate coverage report if requested
if [[ "$COVERAGE" == true ]]; then
    print_info "Generating code coverage report..."
    
    COVERAGE_DIR="${BUILD_DIR}/Coverage"
    mkdir -p "$COVERAGE_DIR"
    
    # Find the coverage data
    COVERAGE_FILE=$(find "$BUILD_DIR" -name "*.xccovreport" -print -quit)
    
    if [[ -n "$COVERAGE_FILE" ]]; then
        xcrun xccov view --report --json "$COVERAGE_FILE" > "${COVERAGE_DIR}/coverage.json"
        xcrun xccov view --report "$COVERAGE_FILE" > "${COVERAGE_DIR}/coverage.txt"
        
        # Extract key coverage metrics
        print_info "Coverage Summary:"
        xcrun xccov view --report "$COVERAGE_FILE" | head -20
        
        print_success "Coverage report saved to ${COVERAGE_DIR}/"
    else
        print_warning "No coverage data found"
    fi
fi

# Performance metrics
print_info "Test Performance Metrics:"
if [[ -d "$BUILD_DIR" ]]; then
    find "$BUILD_DIR" -name "*.log" -exec wc -l {} + | tail -1 | awk '{print "Total log lines: " $1}'
    du -sh "$BUILD_DIR" | awk '{print "Build directory size: " $1}'
fi

# Final results
print_header "Test Results Summary"

if [[ $TEST_FAILURES -eq 0 ]]; then
    print_success "All tests passed! 🎉"
    
    # Quick memory usage check
    print_info "Memory usage check:"
    ps -o pid,rss,comm -p $$ | awk 'NR==2 {print "Test runner memory usage: " $2/1024 " MB"}'
    
    echo -e "${GREEN}Ready for deployment! ✅${NC}"
else
    print_error "Test failures detected: $TEST_FAILURES suite(s) failed"
    
    print_info "Debugging tips:"
    echo "1. Check build logs in ${BUILD_DIR}/"
    echo "2. Run with --verbose for detailed output"
    echo "3. Use --clean to ensure clean build"
    echo "4. Check simulator availability: xcrun simctl list devices"
    
    exit 1
fi

# Cleanup old logs (keep last 5 runs)
find "$BUILD_DIR" -name "*.log" -type f -mtime +5 -delete 2>/dev/null || true

print_success "Test run completed successfully!"