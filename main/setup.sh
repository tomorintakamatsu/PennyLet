#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "PennyLet iOS — Project Setup"
echo "==============================="
echo ""

# Check for Xcode
if ! xcodebuild -version &>/dev/null; then
    echo "⚠️  Xcode not found. Install Xcode from the App Store first."
    echo "   Then run: sudo xcode-select -s /Applications/Xcode.app"
    exit 1
fi

echo "✓ Xcode found"

# Check for XcodeGen
if ! which xcodegen &>/dev/null; then
    echo ""
    echo "Installing XcodeGen..."
    brew install xcodegen
fi

echo "✓ XcodeGen ready"

# Generate Xcode project
echo ""
echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "✓  Project generated: PennyLet.xcodeproj"
echo ""
echo "  To open:  open PennyLet.xcodeproj"
echo ""
