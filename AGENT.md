# Agent Prompts — MemoryKeeper

## 🧭 Global Rules

### ✅ Do
- Use Swift 6 strict concurrency mode with Sendable conformance
- Target macOS 15 Sequoia minimum deployment
- Use SwiftData for all persistence with in-memory containers for testing
- Apply SF Pro Rounded/Display/Text typography system per design spec
- Use actors for all service layers (PhotoLibraryService, VisionAnalysisService)

### ❌ Don't
- Do not use UIKit or AppKit except for NSWindow customization
- Do not create network/server code - local-first architecture only
- Do not use iCloud Photos streaming - local library access only
- Do not use third-party dependencies - Apple frameworks only
- Do not block main thread - use structured concurrency throughout

## 🧩 Task Prompts
## Project Foundation & Data Layer

**Context**
Initialize macOS 15+ SwiftUI app with SwiftData schema for photo metadata graph including Photo, DuplicateGroup, Category, Memory entities with relationships

### Universal Agent Prompt
```
_No prompt generated_
```