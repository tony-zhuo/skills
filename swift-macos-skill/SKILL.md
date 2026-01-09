---
name: swift-macos-skill
description: macOS development patterns using Swift, SwiftUI, and AppKit. Covers window management, menu bar apps, screen capture APIs, NSWindow customization, keyboard shortcuts, sandboxing, entitlements, performance optimization, and memory management. Use for any macOS app development task including screenshot tools, utilities, and desktop applications.
---

# macOS Development Patterns

Best practices and patterns for macOS development with Swift.

## Supported Frameworks

| Framework | Usage | Minimum macOS |
|-----------|-------|---------------|
| SwiftUI | Declarative UI, modern apps | macOS 10.15+ |
| AppKit | Native macOS controls, fine control | macOS 10.0+ |
| ScreenCaptureKit | Modern screen capture | macOS 12.3+ |
| CGWindowList | Legacy screen capture | macOS 10.5+ |
| Combine | Reactive programming | macOS 10.15+ |

## Reference Files

- **Swift Conventions**: [references/swift-conventions.md](references/swift-conventions.md) - Naming, optionals, error handling, memory management (ARC, weak/strong)
- **SwiftUI macOS**: [references/swiftui-macos.md](references/swiftui-macos.md) - macOS-specific SwiftUI patterns, Settings, MenuBarExtra, window management
- **AppKit Patterns**: [references/appkit-patterns.md](references/appkit-patterns.md) - NSWindow, NSView, NSViewController, responder chain, drag & drop
- **Screen Capture**: [references/screen-capture.md](references/screen-capture.md) - ScreenCaptureKit, CGWindowListCreateImage, permissions, overlay windows
- **Window Management**: [references/window-management.md](references/window-management.md) - Floating windows, panels, multiple windows, window controllers
- **Sandboxing**: [references/sandboxing.md](references/sandboxing.md) - Entitlements, file access, security-scoped bookmarks, TCC permissions
- **Performance**: [references/performance.md](references/performance.md) - Instruments, memory optimization, async rendering, CALayer

## Key Principles

1. **AppKit + SwiftUI** - Use SwiftUI for views, AppKit for window control
2. **Window Levels** - Understand NSWindow.Level for overlays/panels
3. **Permissions** - Request screen recording permission before capture
4. **Sandbox** - Design for sandbox from the start
5. **Memory** - Profile with Instruments, watch for image memory

## Quick Patterns

### Menu Bar App with SwiftUI

```swift
@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("MyApp", systemImage: "camera.fill") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
}
```

### Floating Overlay Window

```swift
class OverlayWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        
        self.init(window: window)
    }
    
    func showOverlay(in frame: NSRect) {
        window?.setFrame(frame, display: true)
        window?.orderFront(nil)
    }
}
```

### Screen Capture with ScreenCaptureKit

```swift
import ScreenCaptureKit

func captureScreen() async throws -> CGImage {
    // Check permission
    guard CGPreflightScreenCaptureAccess() else {
        CGRequestScreenCaptureAccess()
        throw CaptureError.permissionDenied
    }
    
    // Get available content
    let content = try await SCShareableContent.excludingDesktopWindows(
        false,
        onScreenWindowsOnly: true
    )
    
    guard let display = content.displays.first else {
        throw CaptureError.noDisplay
    }
    
    // Create filter and configuration
    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = Int(display.width) * 2  // Retina
    config.height = Int(display.height) * 2
    config.pixelFormat = kCVPixelFormatType_32BGRA
    
    // Capture
    let image = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    )
    
    return image
}
```

### Global Keyboard Shortcut

```swift
import Carbon

class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                manager.handler?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
        
        var hotkeyID = EventHotKeyID(signature: OSType(0x4D594150), id: 1) // 'MYAP'
        RegisterEventHotKey(keyCode, modifiers, hotkeyID,
                           GetApplicationEventTarget(), 0, &hotkeyRef)
    }
    
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }
}
```

## Related Skills

- **swift-ios-skill** - iOS-specific patterns
- **go-backend-skill** - Backend API development
