# SwiftUI Patterns for iOS

## State Management

### Property Wrappers Comparison

| Wrapper | Owner | Source | Use Case |
|---------|-------|--------|----------|
| `@State` | View | Internal | Simple local state |
| `@Binding` | Parent | External | Two-way binding from parent |
| `@StateObject` | View | Internal | Create ObservableObject |
| `@ObservedObject` | Parent | External | Receive ObservableObject |
| `@EnvironmentObject` | Ancestor | Environment | Shared across view tree |
| `@Environment` | SwiftUI | System | System values (colorScheme, etc.) |

### @State - Local View State

```swift
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") {
                count += 1
            }
        }
    }
}
```

### @Binding - Child Modification

```swift
struct ParentView: View {
    @State private var isOn = false
    
    var body: some View {
        ToggleView(isOn: $isOn)
    }
}

struct ToggleView: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("Toggle", isOn: $isOn)
    }
}
```

### @StateObject vs @ObservedObject

```swift
// Use @StateObject when creating the object
struct ParentView: View {
    @StateObject private var viewModel = ViewModel()
    
    var body: some View {
        ChildView(viewModel: viewModel)
    }
}

// Use @ObservedObject when receiving the object
struct ChildView: View {
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        Text(viewModel.title)
    }
}
```

### @EnvironmentObject - Shared State

```swift
// Define observable object
class AppState: ObservableObject {
    @Published var user: User?
    @Published var isLoggedIn = false
}

// Inject at root
@main
struct MyApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// Use anywhere in hierarchy
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if let user = appState.user {
            Text("Hello, \(user.name)")
        }
    }
}
```

## View Composition

### Extract Subviews

```swift
// ❌ Monolithic view
struct ContentView: View {
    var body: some View {
        VStack {
            // 100 lines of header code
            // 100 lines of body code
            // 100 lines of footer code
        }
    }
}

// ✅ Composed views
struct ContentView: View {
    var body: some View {
        VStack {
            HeaderView()
            BodyView()
            FooterView()
        }
    }
}

private struct HeaderView: View {
    var body: some View { /* ... */ }
}
```

### ViewBuilder for Custom Containers

```swift
struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Usage
Card {
    Text("Title")
    Text("Subtitle")
    Button("Action") { }
}
```

### View Modifiers

```swift
// Custom modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// Usage
Text("Hello")
    .cardStyle()
```

## Navigation

### NavigationStack (iOS 16+)

```swift
struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(value: item) {
                    Text(item.title)
                }
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(item: item)
            }
            .navigationDestination(for: User.self) { user in
                UserView(user: user)
            }
        }
    }
    
    // Programmatic navigation
    func navigateToItem(_ item: Item) {
        path.append(item)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}
```

### Sheet and FullScreenCover

```swift
struct ContentView: View {
    @State private var showSheet = false
    @State private var selectedItem: Item?
    
    var body: some View {
        Button("Show Sheet") {
            showSheet = true
        }
        .sheet(isPresented: $showSheet) {
            SheetView()
        }
        // Item-based presentation
        .sheet(item: $selectedItem) { item in
            DetailView(item: item)
        }
    }
}
```

## Lists and Collections

### Dynamic Lists

```swift
struct ItemListView: View {
    @State private var items: [Item] = []
    
    var body: some View {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
            }
            .onDelete(perform: deleteItems)
            .onMove(perform: moveItems)
        }
        .toolbar {
            EditButton()
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}
```

### LazyVStack/LazyHStack for Performance

```swift
// ❌ Loads all items immediately
ScrollView {
    VStack {
        ForEach(largeDataSet) { item in
            ExpensiveView(item: item)
        }
    }
}

// ✅ Lazy loading
ScrollView {
    LazyVStack {
        ForEach(largeDataSet) { item in
            ExpensiveView(item: item)
        }
    }
}
```

## Async Data Loading

### Task Modifier

```swift
struct UserView: View {
    let userId: String
    @State private var user: User?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let user {
                UserContent(user: user)
            } else {
                Text("Failed to load")
            }
        }
        .task {
            await loadUser()
        }
        .refreshable {
            await loadUser()
        }
    }
    
    private func loadUser() async {
        isLoading = true
        defer { isLoading = false }
        user = try? await UserService.fetch(id: userId)
    }
}
```

### Task Cancellation

```swift
struct SearchView: View {
    @State private var query = ""
    @State private var results: [Result] = []
    
    var body: some View {
        List(results) { result in
            Text(result.title)
        }
        .searchable(text: $query)
        .task(id: query) { // Cancels previous task when query changes
            guard !query.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300)) // Debounce
            
            guard !Task.isCancelled else { return }
            results = await search(query: query)
        }
    }
}
```

## Animations

### Implicit Animations

```swift
struct AnimatedView: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Rectangle()
                .frame(height: isExpanded ? 200 : 100)
                .animation(.spring(), value: isExpanded)
            
            Button("Toggle") {
                isExpanded.toggle()
            }
        }
    }
}
```

### Explicit Animations

```swift
Button("Animate") {
    withAnimation(.easeInOut(duration: 0.3)) {
        isExpanded.toggle()
    }
}
```

### Transitions

```swift
struct ContentView: View {
    @State private var showDetail = false
    
    var body: some View {
        VStack {
            if showDetail {
                DetailView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))
            }
            
            Button("Toggle") {
                withAnimation {
                    showDetail.toggle()
                }
            }
        }
    }
}
```

## Preferences and Geometry

### GeometryReader

```swift
struct ResponsiveView: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if geometry.size.width > 600 {
                    Sidebar()
                        .frame(width: 250)
                }
                MainContent()
            }
        }
    }
}
```

### PreferenceKey for Child-to-Parent Communication

```swift
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ChildView: View {
    var body: some View {
        Text("Hello")
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: geometry.size)
                }
            )
    }
}

struct ParentView: View {
    @State private var childSize: CGSize = .zero
    
    var body: some View {
        ChildView()
            .onPreferenceChange(SizePreferenceKey.self) { size in
                childSize = size
            }
    }
}
```
