#!/bin/bash
echo "🎨 Running SwiftFormat..."
swiftformat .

echo "🧹 Running SwiftLint (auto-fix)..."
swiftlint --fix

echo "✅ Formatting complete!"
