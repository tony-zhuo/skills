# Window Management for macOS

## NSWindow Basics

### Window Style Masks

```swift
// Standard window
let standardWindow = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)

// Borderless window (for overlays, HUDs)
let borderlessWindow = NSWindow(
    contentRect: .zero,
    styleMask: .borderless,
    backing: .buffered,
    defer: false
)

// Panel (utility window)
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
    styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
```

### Window Levels

```swift
// Common window levels (from back to front)
window.level = .normal           // Standard windows
window.level = .floating         // Utility panels
window.level = .modalPanel       // Modal dialogs
window.level = .mainMenu         // Menu bar level
window.level = .statusBar        // Status bar items
window.level = .popUpMenu        // Popup menus
window.level = .screenSaver      // Screensaver level

// Custom level for overlays
window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
```

### Window Collection Behavior

```swift
// Join all spaces (visible on all desktops)
window.collectionBehavior = [.canJoinAllSpaces]

// Fullscreen support
window.collectionBehavior = [.fullScreenPrimary]
window.collectionBehavior = [.fullScreenAuxiliary]  // Can be tiled

// Transient (temporary, doesn't show in Mission Control)
window.collectionBehavior = [.transient]

// Move to active space
window.collectionBehavior = [.moveToActiveSpace]

// Combined for overlay
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
```

## Floating/Overlay Windows

### Basic Overlay Window

```swift
class OverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = false
        ignoresMouseEvents = true  // Click-through
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}
```

### Interactive Overlay

```swift
class InteractiveOverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = true
        
        // Accept mouse events
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        
        // Don't become key window unless clicked
        // Use NSPanel for this behavior
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

### Transparent Panel (Non-Activating)

```swift
class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hidesOnDeactivate = false
        
        // Floating behavior
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
    }
    
    override var canBecomeKey: Bool { true }
}
```

## Window Controllers

### NSWindowController Pattern

```swift
class EditorWindowController: NSWindowController {
    private let viewModel: EditorViewModel
    
    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        window?.title = "Editor"
        window?.center()
        window?.setFrameAutosaveName("EditorWindow")
        
        // SwiftUI content
        let contentView = EditorView(viewModel: viewModel)
        window?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

### Managing Multiple Windows

```swift
class WindowManager {
    static let shared = WindowManager()
    
    private var windowControllers: [String: NSWindowController] = [:]
    
    func showWindow(id: String, create: () -> NSWindowController) {
        if let existing = windowControllers[id] {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
        } else {
            let controller = create()
            windowControllers[id] = controller
            controller.showWindow(nil)
        }
    }
    
    func closeWindow(id: String) {
        windowControllers[id]?.close()
        windowControllers.removeValue(forKey: id)
    }
    
    func closeAllWindows() {
        windowControllers.values.forEach { $0.close() }
        windowControllers.removeAll()
    }
}
```

## Window Positioning

### Center on Screen

```swift
// Center on main screen
window.center()

// Center on specific screen
if let screen = NSScreen.screens.first(where: { $0.localizedName == "External Display" }) {
    let screenFrame = screen.visibleFrame
    let windowFrame = window.frame
    let x = screenFrame.midX - windowFrame.width / 2
    let y = screenFrame.midY - windowFrame.height / 2
    window.setFrameOrigin(NSPoint(x: x, y: y))
}
```

### Position Relative to Mouse

```swift
func showWindowAtMouse() {
    let mouseLocation = NSEvent.mouseLocation
    
    // Position window with top-left at mouse
    let windowSize = window.frame.size
    let origin = NSPoint(
        x: mouseLocation.x,
        y: mouseLocation.y - windowSize.height
    )
    
    window.setFrameOrigin(origin)
    window.orderFront(nil)
}
```

### Constrain to Screen

```swift
func constrainWindowToScreen() {
    guard let window = window,
          let screen = window.screen ?? NSScreen.main else { return }
    
    var frame = window.frame
    let screenFrame = screen.visibleFrame
    
    // Constrain to screen bounds
    if frame.maxX > screenFrame.maxX {
        frame.origin.x = screenFrame.maxX - frame.width
    }
    if frame.minX < screenFrame.minX {
        frame.origin.x = screenFrame.minX
    }
    if frame.maxY > screenFrame.maxY {
        frame.origin.y = screenFrame.maxY - frame.height
    }
    if frame.minY < screenFrame.minY {
        frame.origin.y = screenFrame.minY
    }
    
    window.setFrame(frame, display: true)
}
```

## Window Appearance

### Transparent/Blurred Background

```swift
class BlurredWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        backgroundColor = .clear
        
        // Add visual effect view for blur
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        
        contentView = visualEffect
    }
}
```

### Custom Title Bar

```swift
class CustomTitleBarWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Custom title bar view
        if let titlebarContainer = standardWindowButton(.closeButton)?.superview?.superview {
            let customView = CustomTitleBarView()
            titlebarContainer.addSubview(customView)
            customView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: titlebarContainer.leadingAnchor, constant: 70),
                customView.trailingAnchor.constraint(equalTo: titlebarContainer.trailingAnchor),
                customView.topAnchor.constraint(equalTo: titlebarContainer.topAnchor),
                customView.bottomAnchor.constraint(equalTo: titlebarContainer.bottomAnchor)
            ])
        }
    }
}
```

## Fullscreen

### Programmatic Fullscreen

```swift
// Toggle fullscreen
func toggleFullscreen() {
    window?.toggleFullScreen(nil)
}

// Check if fullscreen
var isFullscreen: Bool {
    window?.styleMask.contains(.fullScreen) ?? false
}

// Observe fullscreen changes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(windowDidEnterFullScreen),
    name: NSWindow.didEnterFullScreenNotification,
    object: window
)

NotificationCenter.default.addObserver(
    self,
    selector: #selector(windowDidExitFullScreen),
    name: NSWindow.didExitFullScreenNotification,
    object: window
)

@objc func windowDidEnterFullScreen(_ notification: Notification) {
    // Handle enter fullscreen
}

@objc func windowDidExitFullScreen(_ notification: Notification) {
    // Handle exit fullscreen
}
```

## Window Delegates

### NSWindowDelegate

```swift
class MyWindowController: NSWindowController, NSWindowDelegate {
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Return false to prevent close
        return confirmClose()
    }
    
    func windowWillClose(_ notification: Notification) {
        // Cleanup before close
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became active
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Window became inactive
    }
    
    func windowDidMove(_ notification: Notification) {
        // Save position
        saveWindowPosition()
    }
    
    func windowDidResize(_ notification: Notification) {
        // Handle resize
    }
}
```

## Multiple Monitors

### Get All Screens

```swift
// All screens
let allScreens = NSScreen.screens

// Main screen (with menu bar)
let mainScreen = NSScreen.main

// Screen containing point
func screen(containing point: NSPoint) -> NSScreen? {
    NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
}

// Screen for window
let windowScreen = window.screen
```

### Full Coverage Overlay

```swift
func createFullCoverageOverlay() -> [NSWindow] {
    NSScreen.screens.map { screen in
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        window.isOpaque = false
        window.collectionBehavior = [.canJoinAllSpaces]
        return window
    }
}
```
