# Screen Capture for macOS

## Permission Handling

### Check and Request Permission

```swift
import ScreenCaptureKit

class ScreenCapturePermission {
    static func checkPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    static func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

// Usage in app
func setupScreenCapture() {
    if !ScreenCapturePermission.checkPermission() {
        // Show permission dialog
        ScreenCapturePermission.requestPermission()
        
        // Or direct to System Preferences
        ScreenCapturePermission.openSystemPreferences()
    }
}
```

## ScreenCaptureKit (macOS 12.3+)

### Full Screen Capture

```swift
import ScreenCaptureKit

actor ScreenCapturer {
    func captureFullScreen() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = Int(display.width) * 2  // Retina
        config.height = Int(display.height) * 2
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
}
```

### Region Capture

```swift
func captureRegion(_ rect: CGRect, on display: SCDisplay) async throws -> CGImage {
    let filter = SCContentFilter(display: display, excludingWindows: [])
    
    let config = SCStreamConfiguration()
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    
    // Set capture region
    config.sourceRect = rect
    config.width = Int(rect.width * scale)
    config.height = Int(rect.height * scale)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = false
    
    return try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    )
}
```

### Window Capture

```swift
func captureWindow(_ window: SCWindow) async throws -> CGImage {
    let filter = SCContentFilter(desktopIndependentWindow: window)
    
    let config = SCStreamConfiguration()
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    
    config.width = Int(CGFloat(window.frame.width) * scale)
    config.height = Int(CGFloat(window.frame.height) * scale)
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = false
    config.capturesShadowsOnly = false
    config.shouldBeOpaque = true
    
    return try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: config
    )
}
```

### Stream Capture (Real-time)

```swift
class ScreenStreamCapture: NSObject, SCStreamDelegate, SCStreamOutput {
    private var stream: SCStream?
    var onFrame: ((CMSampleBuffer) -> Void)?
    
    func startStream(for display: SCDisplay) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = Int(display.width) * 2
        config.height = Int(display.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)  // 60 FPS
        config.queueDepth = 3
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try await stream?.startCapture()
    }
    
    func stopStream() async throws {
        try await stream?.stopCapture()
        stream = nil
    }
    
    // SCStreamOutput
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        onFrame?(sampleBuffer)
    }
    
    // SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped: \(error)")
    }
}
```

## CGWindowList (Legacy, macOS 10.5+)

### Capture All Screens

```swift
func captureAllScreens() -> CGImage? {
    CGWindowListCreateImage(
        .infinite,
        .optionOnScreenOnly,
        kCGNullWindowID,
        .bestResolution
    )
}
```

### Capture Specific Window

```swift
func captureWindow(windowID: CGWindowID) -> CGImage? {
    CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        windowID,
        [.boundsIgnoreFraming, .bestResolution]
    )
}
```

### Get Window List

```swift
func getAllWindows() -> [[String: Any]] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    return windowList
}

// Get specific window info
func findWindow(named name: String) -> CGWindowID? {
    let windows = getAllWindows()
    for window in windows {
        if let windowName = window[kCGWindowName as String] as? String,
           windowName.contains(name),
           let windowID = window[kCGWindowNumber as String] as? CGWindowID {
            return windowID
        }
    }
    return nil
}
```

## Region Selection Overlay

### Selection Window

```swift
class RegionSelectionController: NSWindowController {
    private var selectionView: RegionSelectionView!
    var onSelectionComplete: ((CGRect) -> Void)?
    
    convenience init() {
        // Create borderless, transparent window covering all screens
        let screenFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.init(window: window)
        
        selectionView = RegionSelectionView()
        selectionView.delegate = self
        window.contentView = selectionView
    }
    
    func startSelection() {
        window?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
    }
    
    func endSelection() {
        NSCursor.pop()
        window?.orderOut(nil)
    }
}

class RegionSelectionView: NSView {
    weak var delegate: RegionSelectionController?
    
    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        
        currentRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 10, currentRect.height > 10 else { return }
        
        // Convert to screen coordinates
        let screenRect = window?.convertToScreen(currentRect) ?? currentRect
        delegate?.onSelectionComplete?(screenRect)
        delegate?.endSelection()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Draw semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Clear selection area
        if currentRect.width > 0 {
            NSColor.clear.setFill()
            currentRect.fill(using: .clear)
            
            // Draw border
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: currentRect)
            path.lineWidth = 2
            path.stroke()
            
            // Draw dimensions
            let dimensions = String(format: "%.0f × %.0f", currentRect.width, currentRect.height)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            dimensions.draw(at: NSPoint(x: currentRect.midX - 30, y: currentRect.maxY + 5), withAttributes: attrs)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            delegate?.endSelection()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
}
```

## Image Processing

### CGImage to NSImage

```swift
extension CGImage {
    func toNSImage() -> NSImage {
        NSImage(cgImage: self, size: NSSize(width: width, height: height))
    }
}
```

### Save to File

```swift
func saveImage(_ image: CGImage, to url: URL, format: ImageFormat) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        format.uti,
        1,
        nil
    ) else {
        throw SaveError.createDestinationFailed
    }
    
    CGImageDestinationAddImage(destination, image, format.options as CFDictionary?)
    
    guard CGImageDestinationFinalize(destination) else {
        throw SaveError.finalizeFailed
    }
}

enum ImageFormat {
    case png
    case jpeg(quality: CGFloat)
    case tiff
    
    var uti: CFString {
        switch self {
        case .png: return kUTTypePNG
        case .jpeg: return kUTTypeJPEG
        case .tiff: return kUTTypeTIFF
        }
    }
    
    var options: [CFString: Any]? {
        switch self {
        case .jpeg(let quality):
            return [kCGImageDestinationLossyCompressionQuality: quality]
        default:
            return nil
        }
    }
}
```

### Copy to Clipboard

```swift
func copyToClipboard(_ image: CGImage) {
    let nsImage = image.toNSImage()
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([nsImage])
}
```

## Memory Management for Images

### Efficient Image Handling

```swift
class ImageCache {
    private let cache = NSCache<NSString, NSImage>()
    
    init() {
        // Limit cache size
        cache.countLimit = 10
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
    }
    
    func store(_ image: CGImage, for key: String) {
        let nsImage = image.toNSImage()
        let cost = image.width * image.height * 4  // Approximate bytes
        cache.setObject(nsImage, forKey: key as NSString, cost: cost)
    }
    
    func retrieve(_ key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}
```

### Autoreleasepool for Batch Operations

```swift
func processManyScreenshots() {
    for i in 0..<100 {
        autoreleasepool {
            if let image = captureScreen() {
                processImage(image)
                // Image released at end of autoreleasepool
            }
        }
    }
}
```

## Retina/HiDPI Handling

```swift
func captureWithCorrectScale() async throws -> CGImage {
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    
    let content = try await SCShareableContent.current
    guard let display = content.displays.first else {
        throw CaptureError.noDisplay
    }
    
    let config = SCStreamConfiguration()
    config.width = Int(CGFloat(display.width) * scale)
    config.height = Int(CGFloat(display.height) * scale)
    
    // ... rest of capture
}

// Convert screen points to pixel coordinates
func pointsToPixels(_ rect: CGRect) -> CGRect {
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    return CGRect(
        x: rect.origin.x * scale,
        y: rect.origin.y * scale,
        width: rect.width * scale,
        height: rect.height * scale
    )
}
```
