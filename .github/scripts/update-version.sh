#!/bin/bash
set -e

# Get version from git tags
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")

# Path to the version file
VERSION_FILE="Sources/FingerStringCLI/Version.swift"

# Update the version file
echo "public let version = \"$VERSION\"" > "$VERSION_FILE"

echo "Updated $VERSION_FILE with version: $VERSION"