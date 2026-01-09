---
name: swift-ios-skill
description: iOS development patterns using Swift and SwiftUI/UIKit. Covers app architecture (MVVM, MVC), UI patterns, navigation, data persistence, networking, push notifications, permissions handling, testing strategies, and App Store guidelines. Use for any iOS app development task.
---

# iOS Development Patterns

Best practices and patterns for iOS development with Swift.

## Supported Frameworks

| Framework | Usage | Minimum iOS |
|-----------|-------|-------------|
| SwiftUI | Declarative UI, modern apps | iOS 13+ |
| UIKit | Imperative UI, fine control | iOS 2+ |
| Combine | Reactive programming | iOS 13+ |
| async/await | Modern concurrency | iOS 13+ |
| Core Data | Local persistence | iOS 3+ |
| SwiftData | Modern persistence | iOS 17+ |

## Reference Files

- **Swift Conventions**: [references/swift-conventions.md](references/swift-conventions.md) - Naming, optionals, error handling, memory management (ARC, weak/strong)
- **SwiftUI Patterns**: [references/swiftui-patterns.md](references/swiftui-patterns.md) - View composition, state management (@State, @Binding, @StateObject, @ObservedObject, @EnvironmentObject), navigation, animations
- **UIKit Patterns**: [references/uikit-patterns.md](references/uikit-patterns.md) - View controllers, Auto Layout, table/collection views, delegates
- **Architecture**: [references/architecture.md](references/architecture.md) - MVVM, MVC, Clean Architecture, dependency injection
- **Networking**: [references/networking.md](references/networking.md) - URLSession, async/await, Codable, error handling
- **Persistence**: [references/persistence.md](references/persistence.md) - UserDefaults, Core Data, SwiftData, Keychain
- **Testing**: [references/testing.md](references/testing.md) - XCTest, UI testing, mocking, TDD patterns

## Key Principles

1. **Protocol-Oriented** - Prefer protocols over inheritance
2. **Value Types** - Use structs for data, classes for identity
3. **Optionals** - Embrace optionals, avoid force unwrapping
4. **Memory** - Understand ARC, use weak/unowned to break cycles
5. **Concurrency** - Prefer async/await over completion handlers

## Quick Patterns

### SwiftUI View with ViewModel

```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await apiService.fetchItems()
        } catch {
            self.error = error
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        List(viewModel.items) { item in
            ItemRow(item: item)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadItems()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }
}
```

### Dependency Injection

```swift
protocol APIServiceProtocol {
    func fetchItems() async throws -> [Item]
}

final class APIService: APIServiceProtocol {
    func fetchItems() async throws -> [Item] {
        // Implementation
    }
}

// In ViewModel
@MainActor
final class ContentViewModel: ObservableObject {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
}

// In tests
class MockAPIService: APIServiceProtocol {
    var mockItems: [Item] = []
    func fetchItems() async throws -> [Item] { mockItems }
}
```

## Related Skills

- **swift-macos-skill** - macOS-specific patterns with AppKit
- **go-backend-skill** - Backend API development
