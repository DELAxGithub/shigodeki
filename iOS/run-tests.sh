#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -eo pipefail

PROJECT_NAME="shigodeki.xcodeproj"
SCHEME="shigodeki"
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.6"

LOG_DIR="build"
LOG_FILE="$LOG_DIR/tests.log"

echo "🚀 Starting Test Execution..."
echo "--------------------------------------------------"
echo "Project: $PROJECT_NAME"
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"
echo "--------------------------------------------------"

# Create log directory
mkdir -p "$LOG_DIR"

# Clean previous logs
rm -f "$LOG_FILE"

# Run tests and capture output to a file and stdout
# The `xcodebuild` command can return exit code 0 even if no tests are run,
# so we must parse the log to verify execution.
echo "🏃 Running xcodebuild..."
xcodebuild test \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO | tee "$LOG_FILE"

echo "📊 Analyzing test results..."

# Check if any test suites were actually started.
# This is the critical check to ensure the test target is configured and running.
EXECUTED_SUITES_COUNT=$(grep -c "Test Suite '.*' started at" "$LOG_FILE" || true)

# Check for test failures
FAILED_TESTS_COUNT=$(grep -c "Test Case '.*' failed" "$LOG_FILE" || true)

echo "--------------------------------------------------"
echo "Test Execution Summary:"
echo "  - Test Suites Executed: $EXECUTED_SUITES_COUNT"
echo "  - Tests Failed: $FAILED_TESTS_COUNT"
echo "--------------------------------------------------"

if [ "$EXECUTED_SUITES_COUNT" -eq 0 ]; then
  echo "❌ FATAL: No test suites were executed."
  echo "   This indicates a critical problem, such as:"
  echo "   - The 'shigodekiTests' target is missing or not configured."
  echo "   - No tests are assigned to the test target."
  echo "   - The test plan '$SCHEME' is not correctly set up."
  exit 1
fi

if [ "$FAILED_TESTS_COUNT" -gt 0 ]; then
    echo "❌ Some tests failed. See log for details: $LOG_FILE"
    exit 1
fi

echo "✅ All executed tests passed successfully."
echo "✅ Test infrastructure is confirmed to be operational."