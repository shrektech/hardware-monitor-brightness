#!/bin/bash
# Build .plasmoid package for KDE Store / Pling release
set -e

VERSION="1.0.0"
PACKAGE_NAME="luminar-v${VERSION}.plasmoid"

echo "Building ${PACKAGE_NAME}..."
rm -f "../${PACKAGE_NAME}"

zip -r "../${PACKAGE_NAME}" metadata.json icon.svg contents/ -x "*.tmp" -x "*.pyc" -x "__pycache__/*"

echo "Release package created successfully at: $(realpath ../${PACKAGE_NAME})"
