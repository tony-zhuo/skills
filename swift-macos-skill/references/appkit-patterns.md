# AppKit Patterns for macOS

## NSView Fundamentals

### Custom View

```swift
class CustomView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Custom drawing
        NSColor.systemBlue.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 10), xRadius: 8, yRadius: 8)
        path.fill()
    }
    
    override var isFlipped: Bool { true }  // Top-left origin like iOS
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove old tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }
        
        // Add new tracking area
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Handle mouse enter
    }
    
    override func mouseExited(with event: NSEvent) {
        // Handle mouse exit
    }
}
```

### Layer-Backed View

```swift
class LayerBackedView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = NSColor.red.cgColor
        layer.cornerRadius = 10
        return layer
    }
    
    // Animate properties
    func animateColor(to color: NSColor) {
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = layer?.backgroundColor
        animation.toValue = color.cgColor
        animation.duration = 0.3
        layer?.add(animation, forKey: "colorChange")
        layer?.backgroundColor = color.cgColor
    }
}
```

## NSViewController

### Basic View Controller

```swift
class ContentViewController: NSViewController {
    private lazy var stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        // Called before view appears
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Called after view appears
    }
    
    private func setupUI() {
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
}
```

### Child View Controllers

```swift
class ContainerViewController: NSViewController {
    private var currentChild: NSViewController?
    
    func showChild(_ child: NSViewController) {
        // Remove existing
        currentChild?.view.removeFromSuperview()
        currentChild?.removeFromParent()
        
        // Add new
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.width, .height]
        view.addSubview(child.view)
        
        currentChild = child
    }
    
    func transitionToChild(_ child: NSViewController) {
        guard let current = currentChild else {
            showChild(child)
            return
        }
        
        addChild(child)
        child.view.frame = view.bounds
        
        transition(
            from: current,
            to: child,
            options: .crossfade
        ) {
            current.removeFromParent()
            self.currentChild = child
        }
    }
}
```

## Responder Chain

### First Responder

```swift
class EditableView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        // Called when becoming first responder
        layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
        layer?.borderWidth = 2
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        // Called when resigning first responder
        layer?.borderWidth = 0
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            window?.makeFirstResponder(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
```

### Action Chain

```swift
// In view
override func doCommand(by selector: Selector) {
    if selector == #selector(NSResponder.cancelOperation(_:)) {
        // Handle Escape
        return
    }
    super.doCommand(by: selector)
}

// In app delegate (catches all unhandled actions)
@objc func handleCustomAction(_ sender: Any?) {
    // Global action handler
}

// Check responder chain
func findResponder(for action: Selector) -> NSResponder? {
    var responder: NSResponder? = NSApp.keyWindow?.firstResponder
    while let current = responder {
        if current.responds(to: action) {
            return current
        }
        responder = current.nextResponder
    }
    return nil
}
```

## Drag and Drop

### Dragging Source

```swift
class DraggableView: NSView, NSDraggingSource {
    override func mouseDown(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString("Drag content", forType: .string)
        
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: snapshot())
        
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : .copy
    }
    
    private func snapshot() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()
        return image
    }
}
```

### Drop Destination

```swift
class DropTargetView: NSView {
    private var isHighlighted = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string, .fileURL])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string, .fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isHighlighted = true
        needsDisplay = true
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        needsDisplay = true
        
        let pasteboard = sender.draggingPasteboard
        
        // Handle file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            handleDroppedFiles(urls)
            return true
        }
        
        // Handle strings
        if let string = pasteboard.string(forType: .string) {
            handleDroppedString(string)
            return true
        }
        
        return false
    }
    
    private func handleDroppedFiles(_ urls: [URL]) {
        // Process dropped files
    }
    
    private func handleDroppedString(_ string: String) {
        // Process dropped string
    }
}
```

## Menus

### Context Menu

```swift
class ContextMenuView: NSView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Delete", action: #selector(delete(_:)), keyEquivalent: "")
        
        return menu
    }
    
    @objc override func copy(_ sender: Any?) {
        // Handle copy
    }
    
    @objc override func paste(_ sender: Any?) {
        // Handle paste
    }
    
    @objc func delete(_ sender: Any?) {
        // Handle delete
    }
}
```

### Dynamic Menu

```swift
class MenuManager: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    
    override init() {
        super.init()
        menu.delegate = self
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        // Add dynamic items
        let items = fetchItems()
        for item in items {
            let menuItem = NSMenuItem(title: item.name, action: #selector(itemSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            menu.addItem(menuItem)
        }
    }
    
    @objc private func itemSelected(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? Item else { return }
        handleSelection(item)
    }
}
```

## Status Bar Item

### NSStatusItem

```swift
class StatusBarController {
    private var statusItem: NSStatusItem?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Screenshot")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            performAction()
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // Clear so left-click works again
    }
    
    @objc private func performAction() {
        // Handle left click
    }
    
    @objc private func openSettings() {
        // Open settings
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

## Auto Layout in AppKit

### Programmatic Constraints

```swift
class LayoutView: NSView {
    private let label = NSTextField(labelWithString: "Label")
    private let button = NSButton(title: "Button", target: nil, action: nil)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        addSubview(button)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])
    }
}
```

### Stack Views

```swift
class StackLayoutView: NSView {
    private lazy var stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    func addItem(_ view: NSView) {
        stackView.addArrangedSubview(view)
    }
    
    func removeItem(_ view: NSView) {
        stackView.removeArrangedSubview(view)
        view.removeFromSuperview()
    }
}
```
