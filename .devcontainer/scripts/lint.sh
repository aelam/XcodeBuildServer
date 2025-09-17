#!/bin/bash
echo "🧹 Running SwiftLint..."
swiftlint

echo "🎨 Running SwiftFormat (check mode)..."
swiftformat --lint .

echo "✅ Linting complete!"
