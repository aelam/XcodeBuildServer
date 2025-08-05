# XcodeProjectManagement Tests

This directory contains tests for the XcodeProjectManagement module.

## Test Strategy

The tests are designed to be robust across different environments, including:

- **Local Development**: Full functionality testing with Xcode available
- **CI/CD Environments**: Graceful degradation when Xcode is not available

## Test Categories

### 1. Project Discovery Tests (`XcodeProjectLocatorTests`)
- Tests project and workspace discovery logic
- Works without xcodebuild dependency
- Tests error handling for missing projects

### 2. Command Building Tests (`XcodeBuildCommandBuilderTests`) 
- Tests xcodebuild command argument generation
- Pure unit tests without external dependencies
- Validates all build options and destinations

### 3. Project Management Tests (`XcodeProjectManagerTests`)
- Tests high-level project management operations
- **Environment-aware**: Automatically detects xcodebuild availability
- Gracefully handles CI environments without Xcode

## CI Environment Handling

The tests use intelligent detection to handle environments without Xcode:

```swift
private func isXcodeBuildAvailable() -> Bool {
    // Check if we're in CI environment
    if ProcessInfo.processInfo.environment["CI"] != nil {
        return false
    }
    
    // Verify xcodebuild exists and can run
    // ...
}
```

### Behavior in CI:
- **Project loading tests**: Skip scheme resolution expectations
- **xcodebuild-dependent tests**: Skip entirely or catch/ignore errors
- **Core functionality**: Still tests project discovery and command building

## Running Tests

### Locally (with Xcode):
```bash
swift test
```
All tests run and validate full functionality.

### CI Environment:
```bash
CI=true swift test
```
Tests automatically adapt to limited environment.

## Test Files

- `XcodeProjectLocatorTests.swift` - Project discovery tests
- `XcodeProjectManagerTests.swift` - High-level management tests  
- `XcodeBuildCommandBuilderTests.swift` - Command building tests

## Adding New Tests

When adding tests that depend on xcodebuild:

1. Use `isXcodeBuildAvailable()` guard
2. Add error handling for CI environments
3. Focus on testing logic that doesn't require Xcode installation
4. Document any environment-specific behavior