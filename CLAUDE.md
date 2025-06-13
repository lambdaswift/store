# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift package named "Store" that uses Swift Package Manager (SPM) as its build system. The project requires Swift 6.1 or later.

## Commands

### Build
```bash
swift build
```

### Run Tests
```bash
swift test
```

### Run Tests with Verbose Output
```bash
swift test --verbose
```

### Clean Build
```bash
swift package clean
```

### Generate Xcode Project (if needed)
```bash
swift package generate-xcodeproj
```

## Architecture

The package follows the standard Swift Package Manager structure:

- **Sources/Store/**: Contains the main library code
- **Tests/StoreTests/**: Contains unit tests using the Swift Testing framework (not XCTest)
  - Tests use `@Test` attribute and `#expect` assertions
  - Import test modules with `@testable import Store`

## Testing Notes

This project uses the new Swift Testing framework instead of XCTest. When writing tests:
- Use `@Test` attribute to mark test functions
- Use `#expect` for assertions
- Test functions don't need to start with "test" prefix