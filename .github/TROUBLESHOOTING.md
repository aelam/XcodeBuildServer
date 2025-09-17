# GitHub Actions Troubleshooting Guide

This guide helps you resolve common issues with the GitHub Actions workflows in sourcekit-bsp.

## Common Issues and Solutions

### 1. SwiftLint Container Action Error

**Error:** `Container action is only supported on Linux`

**Cause:** The `norio-nomura/action-swiftlint` action uses Docker containers which don't work on macOS runners.

**Solution:** We've updated the workflows to install SwiftLint via Homebrew instead:

```yaml
- name: Install SwiftLint
  run: brew install swiftlint

- name: Run SwiftLint
  run: swiftlint --strict --reporter github-actions-logging
```

### 2. Build Failures

**Error:** Swift build fails with compilation errors

**Solutions:**

1. **Check Swift Version Compatibility:**
   ```bash
   # Locally test with the same Swift version as CI
   swift --version
   swift build
   ```

2. **Clean Build:**
   ```bash
   swift package clean
   swift build
   ```

3. **Check Dependencies:**
   ```bash
   swift package resolve
   swift package show-dependencies
   ```

### 3. Missing Secrets/Tokens

**Error:** Workflows fail due to missing environment variables

**Solutions:**

1. **Use Basic CI:** Switch to `basic-ci.yml` which doesn't require external tokens
2. **Configure Required Secrets:**
   - Go to repository Settings → Secrets and variables → Actions
   - Add required secrets:
     - `CODECOV_TOKEN` (optional, for code coverage)
     - `SEMGREP_APP_TOKEN` (optional, for security scanning)

### 4. Test Failures

**Error:** `swift test` command fails

**Solutions:**

1. **Run Tests Locally:**
   ```bash
   swift test --enable-code-coverage
   ```

2. **Check Test Dependencies:**
   ```bash
   swift package resolve
   swift test --list-tests
   ```

3. **Isolate Failing Tests:**
   ```bash
   swift test --filter TestClassName.testMethodName
   ```

### 5. Artifact Upload Issues

**Error:** Artifacts not uploading or wrong paths

**Solutions:**

1. **Verify Paths:**
   ```bash
   # Check if the binary exists
   ls -la .build/release/
   ```

2. **Update Artifact Paths:**
   ```yaml
   - name: Upload Build Artifact
     uses: actions/upload-artifact@v4
     with:
       name: xcode-build-server
       path: .build/release/sourcekit-bsp
   ```

### 6. Cache Issues

**Error:** Builds are slow or cache not working

**Solutions:**

1. **Clear Cache:** 
   - Go to Actions tab → Caches
   - Delete old or corrupted caches

2. **Update Cache Keys:**
   ```yaml
   - name: Cache Swift Package Manager
     uses: actions/cache@v4
     with:
       path: |
         .build
         ~/.cache/org.swift.swiftpm
       key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
   ```

### 7. Release Workflow Issues

**Error:** Release workflow not triggering or failing

**Solutions:**

1. **Check Tag Format:**
   ```bash
   # Correct format
   git tag v1.0.0
   git push origin v1.0.0
   
   # Incorrect format
   git tag 1.0.0  # Missing 'v' prefix
   ```

2. **Verify Permissions:**
   - Ensure the repository has write permissions for releases
   - Check that `GITHUB_TOKEN` has appropriate permissions

### 8. SwiftLint Configuration Issues

**Error:** SwiftLint fails with configuration errors

**Solutions:**

1. **Test Configuration Locally:**
   ```bash
   swiftlint lint --config .swiftlint.yml
   ```

2. **Validate YAML:**
   ```bash
   # Use any YAML validator
   yamllint .swiftlint.yml
   ```

3. **Simplify Configuration:**
   - Start with a minimal `.swiftlint.yml`
   - Add rules incrementally

## Debugging Steps

### 1. Enable Debug Logging

Add this to your workflow for more verbose output:

```yaml
- name: Debug Information
  run: |
    echo "Runner OS: ${{ runner.os }}"
    echo "GitHub SHA: ${{ github.sha }}"
    echo "GitHub Ref: ${{ github.ref }}"
    swift --version
    xcodebuild -version
    ls -la .build/ || echo "No .build directory"
```

### 2. Matrix Debugging

Test specific combinations:

```yaml
strategy:
  matrix:
    swift-version: ['5.10']
    # Remove other versions temporarily to isolate issues
```

### 3. Step-by-Step Isolation

Comment out failing steps and re-enable them one by one:

```yaml
# - name: Problematic Step
#   run: some-command

- name: Debug Step
  run: |
    echo "Debugging the issue..."
    # Add debugging commands here
```

## Performance Optimization

### 1. Reduce Matrix Size

```yaml
strategy:
  matrix:
    swift-version: ['5.10']  # Test with one version first
```

### 2. Use Caching Effectively

```yaml
- name: Cache Swift Package Manager
  uses: actions/cache@v4
  with:
    path: |
      .build
      ~/.cache/org.swift.swiftpm
    key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
    restore-keys: |
      ${{ runner.os }}-spm-
```

### 3. Parallel Jobs

```yaml
jobs:
  build:
    # Fast job
  test:
    needs: build  # Only run after build succeeds
    # Test job
```

## Workflow Selection Guide

### Use `basic-ci.yml` when:
- ✅ Getting started with CI/CD
- ✅ No external service tokens available
- ✅ Want simple, reliable builds
- ✅ Focus on core functionality

### Use `ci.yml` when:
- ✅ Need code coverage reporting
- ✅ Have external service tokens configured
- ✅ Want comprehensive testing
- ✅ Ready for advanced features

### Use `code-quality.yml` when:
- ✅ Need strict code quality enforcement
- ✅ Want security scanning
- ✅ Have development team collaboration
- ✅ Ready to maintain quality standards

## Getting Help

### 1. Check Logs
- Go to Actions tab in your repository
- Click on the failed workflow run
- Expand the failing step to see detailed logs

### 2. Local Testing
Always test equivalent commands locally:

```bash
# Test build
swift build -c release

# Test linting
swiftlint --strict

# Test format
swift-format lint --recursive Sources Tests
```

### 3. Community Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Swift Package Manager](https://swift.org/package-manager/)
- [SwiftLint Documentation](https://github.com/realm/SwiftLint)

### 4. Repository Specific Help
- Create an issue with the `ci/cd` label
- Include workflow logs and error messages
- Mention your environment (macOS version, Xcode version, etc.)

## Minimal Working Example

If all else fails, start with this minimal workflow:

```yaml
name: Minimal CI
on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-14
    steps:
    - uses: actions/checkout@v4
    - name: Build
      run: swift build
    - name: Test
      run: swift test
```

Once this works, gradually add more features.

## Prevention Tips

1. **Test Locally First:** Always test changes locally before pushing
2. **Small Incremental Changes:** Add one feature at a time to workflows
3. **Monitor Workflow Health:** Regularly check that workflows are passing
4. **Keep Dependencies Updated:** Update action versions quarterly
5. **Document Changes:** Update this guide when you solve new issues

Remember: CI/CD should make development easier, not harder. Start simple and build complexity gradually!