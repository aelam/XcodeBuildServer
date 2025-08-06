# CI Testing Configuration

## Overview

This document describes how the test suite handles CI environments and ensures reliable testing across different platforms.

## Environment Detection

The test suite automatically detects CI environments using the `CI` environment variable:

```swift
if ProcessInfo.processInfo.environment["CI"] != nil {
    // Skip CI-incompatible tests
    return
}
```

## GitHub Actions Configuration

The CI workflow automatically sets up the required environment:

```yaml
- name: Run Tests
  run: |
    echo "CI environment variable: $CI"
    echo "Running tests in CI mode..."
    swift test --enable-code-coverage
  env:
    CI: true  # Explicitly set CI=true (GitHub Actions sets this automatically)
```

## Test Categories

### ✅ CI-Friendly Tests
- **Basic functionality tests**: Initialization, command execution
- **Logic tests**: Version selection, error handling
- **Concurrency tests**: Multiple instances, thread safety
- **Mock tests**: Using fake data to test behavior

### ⚠️ CI-Conditional Tests
- **`testCustomDeveloperDir`**: Skips in CI, tests DEVELOPER_DIR functionality locally
- **Path-dependent tests**: Skip if required paths don't exist

### 🧪 Test Behaviors in CI

1. **Automatic Skipping**:
   ```swift
   func testCustomDeveloperDir() async throws {
       if ProcessInfo.processInfo.environment["CI"] != nil {
           print("⏭️  Skipping testCustomDeveloperDir in CI environment")
           return
       }
       // ... test implementation
   }
   ```

2. **Conditional Execution**:
   ```swift
   guard FileManager.default.fileExists(atPath: requiredPath) else {
       print("⏭️  Skipping test - required path not found")
       return
   }
   ```

3. **Enhanced Logging**:
   ```swift
   if ProcessInfo.processInfo.environment["CI"] != nil {
       print("🔧 CI Xcode version: \(version)")
   }
   ```

## Running Tests Locally vs CI

### Local Development
```bash
# Run all tests including environment-specific ones
swift test

# Run specific test suite
swift test --filter XcodeToolchainTests
```

### CI Environment Simulation
```bash
# Simulate CI environment locally
CI=true swift test

# Check which tests are skipped
CI=true swift test --filter XcodeToolchainTests 2>&1 | grep "Skipping"
```

## Test Coverage

Even with CI-conditional tests, we maintain high coverage by:

1. **Logic Testing**: Testing the core algorithms with mock data
2. **Error Path Testing**: Verifying error handling with invalid inputs  
3. **Fallback Testing**: Ensuring graceful degradation when resources unavailable
4. **Integration Testing**: Testing component interactions without environment dependencies

## Debugging CI Issues

If tests fail in CI:

1. **Check Environment Variables**:
   ```yaml
   - name: Debug Environment
     run: |
       echo "CI: $CI"
       echo "PATH: $PATH" 
       echo "Available Xcode versions:"
       ls /Applications/ | grep -i xcode || echo "No Xcode installations found"
   ```

2. **Enable Verbose Output**:
   ```bash
   swift test --enable-code-coverage --verbose
   ```

3. **Check Xcode Setup**:
   ```yaml
   - name: Verify Xcode
     run: |
       xcode-select -p
       xcodebuild -version
   ```

## Best Practices

1. **Write CI-agnostic tests**: Use logic testing instead of environment testing
2. **Graceful skipping**: Skip tests that can't run rather than failing
3. **Clear logging**: Print helpful messages when tests are skipped
4. **Fallback behavior**: Test that the system works even when optimal conditions aren't met

## Example Test Pattern

```swift
@Test("Feature works correctly")
func testFeature() async throws {
    // Check CI environment
    let isCI = ProcessInfo.processInfo.environment["CI"] != nil
    
    if isCI {
        // Use CI-friendly test approach
        testFeatureLogicOnly()
    } else {
        // Use full integration test
        testFeatureWithSystemResources()
    }
}
```

This approach ensures reliable CI while maintaining comprehensive testing in development environments.