# SwiftUI Patterns for macOS

## App Structure

### Multi-Window App

```swift
@main
struct MyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("n")
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
        }
        
        // Auxiliary window
        Window("Inspector", id: "inspector") {
            InspectorView()
        }
        .keyboardShortcut("i", modifiers: [.command, .option])
    }
}
```

### Menu Bar Extra (macOS 13+)

```swift
@main
struct MenuBarApp: App {
    var body: some Scene {
        // Menu style (dropdown menu)
        MenuBarExtra("Status", systemImage: "circle.fill") {
            Button("Action 1") { }
            Button("Action 2") { }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        
        // Window style (popover)
        MenuBarExtra("Dashboard", systemImage: "chart.bar") {
            DashboardView()
                .frame(width: 300, height: 400)
        }
        .menuBarExtraStyle(.window)
    }
}
```

### App Delegate Integration

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
        
        // Setup status item if needed
        setupStatusItem()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running as menu bar app
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Screenshot")
    }
}
```

## Window Management

### Opening Windows Programmatically

```swift
// Define window ID
enum WindowID: String {
    case editor = "editor-window"
    case preview = "preview-window"
}

// In App
Window("Editor", id: WindowID.editor.rawValue) {
    EditorView()
}

// Open window
@Environment(\.openWindow) private var openWindow

Button("Open Editor") {
    openWindow(id: WindowID.editor.rawValue)
}

// With value
WindowGroup(for: Document.ID.self) { $documentId in
    if let documentId {
        DocumentView(documentId: documentId)
    }
} defaultValue: {
    Document.ID()
}

// Open with value
openWindow(value: document.id)
```

### Window State

```swift
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab1View()
                .tabItem { Label("Tab 1", systemImage: "1.circle") }
                .tag(0)
            Tab2View()
                .tabItem { Label("Tab 2", systemImage: "2.circle") }
                .tag(1)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// Persist window frame
.defaultPosition(.center)
.defaultSize(width: 800, height: 600)
```

### Window Toolbar

```swift
struct ContentView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: addItem) {
                    Label("Add", systemImage: "plus")
                }
                
                Button(action: share) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Label("Sidebar", systemImage: "sidebar.left")
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar)
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }
}
```

## Settings Window

### Multi-Tab Settings

```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = true
    
    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
            Toggle("Show in Dock", isOn: $showInDock)
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

## Navigation

### NavigationSplitView

```swift
struct MainView: View {
    @State private var selectedItem: Item?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(items, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } content: {
            // Content (optional middle column)
            if let item = selectedItem {
                ItemContentView(item: item)
            } else {
                Text("Select an item")
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 300)
        } detail: {
            // Detail
            if let item = selectedItem {
                ItemDetailView(item: item)
            } else {
                Text("No Selection")
            }
        }
    }
}
```

## Keyboard Shortcuts

### KeyboardShortcut Modifier

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Button("Save") { save() }
                .keyboardShortcut("s")  // ⌘S
            
            Button("Export") { export() }
                .keyboardShortcut("e", modifiers: [.command, .shift])  // ⇧⌘E
            
            Button("Refresh") { refresh() }
                .keyboardShortcut(.return)  // Return key
            
            Button("Cancel") { cancel() }
                .keyboardShortcut(.escape)  // Escape key
        }
    }
}
```

### Custom Commands

```swift
struct ContentView: View {
    var body: some View {
        Text("Content")
            .commands {
                CommandGroup(replacing: .pasteboard) {
                    Button("Copy Special") { copySpecial() }
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                }
                
                CommandMenu("Tools") {
                    Button("Analyze") { analyze() }
                        .keyboardShortcut("a", modifiers: [.command, .option])
                    
                    Button("Validate") { validate() }
                }
            }
    }
}
```

## Drag and Drop

### Draggable and DropDestination

```swift
struct DragDropView: View {
    @State private var items: [Item] = []
    
    var body: some View {
        VStack {
            // Draggable
            ForEach(items) { item in
                ItemView(item: item)
                    .draggable(item)
            }
            
            // Drop target
            DropZoneView()
                .dropDestination(for: Item.self) { items, location in
                    self.items.append(contentsOf: items)
                    return true
                }
        }
    }
}

// File drop
struct FileDropView: View {
    @State private var droppedURLs: [URL] = []
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .dropDestination(for: URL.self) { urls, location in
                droppedURLs = urls
                return true
            }
    }
}
```

## macOS-Specific Modifiers

### Focus and Hover

```swift
struct InteractiveView: View {
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("Input", text: $text)
            .focused($isFocused)
            .onHover { hovering in
                isHovered = hovering
            }
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .onSubmit {
                // Handle return key
            }
    }
}
```

### Context Menu

```swift
struct ItemView: View {
    let item: Item
    
    var body: some View {
        Text(item.name)
            .contextMenu {
                Button("Edit") { edit(item) }
                Button("Duplicate") { duplicate(item) }
                Divider()
                Button("Delete", role: .destructive) { delete(item) }
            }
    }
}
```

## AppKit Integration

### NSViewRepresentable

```swift
struct NSTextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NSTextViewWrapper
        
        init(_ parent: NSTextViewWrapper) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
```

### Hosting SwiftUI in AppKit

```swift
class MyViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swiftUIView = ContentView()
        let hostingController = NSHostingController(rootView: swiftUIView)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
```
