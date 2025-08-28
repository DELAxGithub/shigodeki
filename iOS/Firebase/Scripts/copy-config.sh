#!/bin/bash

# Firebase configuration copy script
# This script copies the appropriate GoogleService-Info.plist based on build configuration

if [ "${CONFIGURATION}" = "Debug" ]; then
    echo "Using Firebase configuration for Development"
    cp "${SRCROOT}/Firebase/Config/GoogleService-Info-Dev.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
else
    echo "Using Firebase configuration for Production"
    cp "${SRCROOT}/Firebase/Config/GoogleService-Info-Prod.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
fi