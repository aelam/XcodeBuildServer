#!/bin/bash
echo "🏗️  Building project..."
swift build

echo "🧪 Running tests..."
swift test --parallel

echo "✅ Build and test complete!"
