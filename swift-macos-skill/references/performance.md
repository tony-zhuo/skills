# Performance Optimization for macOS

## Memory Management

### Autoreleasepool

```swift
// Use for batch operations with temporary objects
func processManyImages() {
    for i in 0..<1000 {
        autoreleasepool {
            let image = loadImage(at: i)
            processImage(image)
            // Memory released at end of each iteration
        }
    }
}

// For async contexts
func processImagesAsync() async {
    for i in 0..<1000 {
        await withCheckedContinuation { continuation in
            autoreleasepool {
                let image = loadImage(at: i)
                processImage(image)
                continuation.resume()
            }
        }
    }
}
```

### Image Memory

```swift
// Downscale large images for display
func createThumbnail(from cgImage: CGImage, maxSize: CGFloat) -> CGImage? {
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    
    let scale = min(maxSize / width, maxSize / height, 1.0)
    let newWidth = Int(width * scale)
    let newHeight = Int(height * scale)
    
    guard let context = CGContext(
        data: nil,
        width: newWidth,
        height: newHeight,
        bitsPerComponent: 8,
        bytesPerRow: newWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    
    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    
    return context.makeImage()
}

// Release image data explicitly
class ImageHolder {
    private var imageData: Data?
    private var cgImage: CGImage?
    
    func clear() {
        cgImage = nil
        imageData = nil
    }
}
```

### NSCache for Caching

```swift
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, NSImage>()
    
    init() {
        cache.countLimit = 50
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
        
        // Clear on memory pressure
        NotificationCenter.default.addObserver(
            forName: NSApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }
    
    func store(_ image: NSImage, for key: String) {
        let cost = estimateCost(image)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func retrieve(_ key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }
    
    private func estimateCost(_ image: NSImage) -> Int {
        let size = image.size
        return Int(size.width * size.height * 4)
    }
}
```

## View Performance

### Avoid Layout Recursion

```swift
// ❌ Can cause layout loop
override func layout() {
    super.layout()
    subview.frame = bounds  // Triggers layout
}

// ✅ Use constraints instead
override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    subview.translatesAutoresizingMaskIntoConstraints = false
    addSubview(subview)
    NSLayoutConstraint.activate([
        subview.topAnchor.constraint(equalTo: topAnchor),
        subview.bottomAnchor.constraint(equalTo: bottomAnchor),
        subview.leadingAnchor.constraint(equalTo: leadingAnchor),
        subview.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])
}
```

### Batch Updates

```swift
// ❌ Multiple redraws
for item in items {
    addSubview(createView(for: item))
    needsDisplay = true
}

// ✅ Single redraw
for item in items {
    addSubview(createView(for: item))
}
needsDisplay = true

// For collection view
collectionView.performBatchUpdates {
    collectionView.insertItems(at: indexPaths)
}
```

### Layer-Backed Views

```swift
class OptimizedView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // Enable layer backing for better performance
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        // Use layer for simple appearance
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 8
    }
    
    // Only use draw() when necessary
    override var wantsUpdateLayer: Bool { true }
    
    override func updateLayer() {
        // Update layer properties directly (faster than draw())
        layer?.backgroundColor = isHighlighted 
            ? NSColor.selectedControlColor.cgColor 
            : NSColor.controlBackgroundColor.cgColor
    }
}
```

## Async Performance

### Task Priority

```swift
// High priority for user-facing work
Task(priority: .userInitiated) {
    await loadVisibleContent()
}

// Low priority for background work
Task(priority: .background) {
    await cleanupCache()
}

// Yield to prevent blocking
func processLargeDataset(_ items: [Item]) async {
    for (index, item) in items.enumerated() {
        process(item)
        
        // Yield every 100 items
        if index % 100 == 0 {
            await Task.yield()
        }
    }
}
```

### Debouncing

```swift
actor Debouncer {
    private var task: Task<Void, Never>?
    
    func debounce(delay: Duration, action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }
}

// Usage
class SearchViewModel {
    private let debouncer = Debouncer()
    
    func search(_ query: String) {
        Task {
            await debouncer.debounce(delay: .milliseconds(300)) {
                await self.performSearch(query)
            }
        }
    }
}
```

### Throttling

```swift
actor Throttler {
    private var lastExecutionTime: ContinuousClock.Instant?
    private let interval: Duration
    
    init(interval: Duration) {
        self.interval = interval
    }
    
    func throttle(_ action: @escaping () async -> Void) async {
        let now = ContinuousClock.now
        
        if let last = lastExecutionTime {
            let elapsed = now - last
            if elapsed < interval {
                return  // Skip
            }
        }
        
        lastExecutionTime = now
        await action()
    }
}
```

## Core Animation

### Implicit Animations

```swift
// Disable implicit animations for immediate updates
CATransaction.begin()
CATransaction.setDisableActions(true)
layer.position = newPosition
CATransaction.commit()

// Or with duration
CATransaction.begin()
CATransaction.setAnimationDuration(0.3)
layer.opacity = 0
CATransaction.commit()
```

### Offscreen Rendering

```swift
// Avoid offscreen rendering when possible
layer.shouldRasterize = true
layer.rasterizationScale = window?.backingScaleFactor ?? 2.0

// Use shadowPath instead of computed shadow
layer.shadowPath = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).cgPath
```

## Instruments Profiling

### Time Profiler

```swift
// Add signposts for profiling
import os

let log = OSLog(subsystem: "com.example.app", category: "Performance")

func captureScreen() async throws -> CGImage {
    os_signpost(.begin, log: log, name: "Screen Capture")
    defer { os_signpost(.end, log: log, name: "Screen Capture") }
    
    // Capture logic
}
```

### Memory Debugging

```swift
// Track allocations
class TrackedObject {
    static var count = 0
    
    init() {
        Self.count += 1
        print("Allocated: \(Self.count)")
    }
    
    deinit {
        Self.count -= 1
        print("Deallocated: \(Self.count)")
    }
}

// Detect leaks with weak reference
weak var weakRef = someObject
someObject = nil
assert(weakRef == nil, "Memory leak detected")
```

## Lazy Loading

### Lazy Properties

```swift
class ViewController {
    // Only created when first accessed
    private lazy var heavyView: HeavyView = {
        let view = HeavyView()
        view.configure()
        return view
    }()
    
    // Lazy with capture (use weak to avoid retain cycle)
    private lazy var handler: () -> Void = { [weak self] in
        self?.handleAction()
    }
}
```

### Lazy Image Loading

```swift
class LazyImageView: NSView {
    private var imageTask: Task<Void, Never>?
    private var image: NSImage?
    
    var imageURL: URL? {
        didSet {
            loadImage()
        }
    }
    
    private func loadImage() {
        imageTask?.cancel()
        image = nil
        
        guard let url = imageURL else { return }
        
        imageTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                
                if let loadedImage = NSImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                        self.needsDisplay = true
                    }
                }
            } catch {
                // Handle error
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds)
    }
}
```

## Startup Optimization

### Defer Non-Essential Work

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Essential startup only
        setupMainWindow()
        
        // Defer non-essential
        DispatchQueue.main.async {
            self.setupAnalytics()
            self.checkForUpdates()
        }
        
        // Background tasks
        Task.detached(priority: .background) {
            await self.warmupCaches()
        }
    }
}
```

### Static vs Dynamic Libraries

```
# Use static linking for faster startup
# In Package.swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "MyLibrary", package: "MyLibrary", type: .static)
    ]
)
```
