# Sandboxing and Entitlements for macOS

## App Sandbox Basics

### Enable Sandbox

In `*.entitlements` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

### Common Entitlements

```xml
<!-- Network access -->
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>

<!-- File access -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- Hardware -->
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
<key>com.apple.security.device.usb</key>
<true/>

<!-- Screen Recording (required for screen capture) -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.apple.screencapture.interactive</string>
</array>

<!-- Accessibility (for global hotkeys) -->
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.apple.systemevents</string>
</array>
```

## Hardened Runtime

For notarization, enable hardened runtime:

```xml
<!-- Hardened Runtime -->
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

## TCC (Transparency, Consent, Control)

### Screen Recording Permission

```swift
import ScreenCaptureKit

class ScreenCapturePermissionManager {
    static func checkPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    static func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
```

### Accessibility Permission

```swift
import ApplicationServices

class AccessibilityPermissionManager {
    static func checkPermission() -> Bool {
        AXIsProcessTrusted()
    }
    
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    static func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

### Full Disk Access

```swift
class FullDiskAccessManager {
    static func checkPermission() -> Bool {
        // Try to access a protected location
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/History.db")
        
        return FileManager.default.isReadableFile(atPath: testPath.path)
    }
    
    static func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
```

## Security-Scoped Bookmarks

### Create Bookmark

```swift
class BookmarkManager {
    private let bookmarksKey = "SecurityScopedBookmarks"
    
    func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        var bookmarks = UserDefaults.standard.dictionary(forKey: bookmarksKey) ?? [:]
        bookmarks[url.path] = bookmarkData
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }
    
    func resolveBookmark(for path: String) -> URL? {
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarksKey),
              let bookmarkData = bookmarks[path] as? Data else {
            return nil
        }
        
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        
        if isStale {
            // Re-create bookmark
            try? saveBookmark(for: url)
        }
        
        return url
    }
}
```

### Access Security-Scoped Resource

```swift
func accessSecurityScopedResource(at url: URL, action: (URL) throws -> Void) throws {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    try action(url)
}

// Usage
try accessSecurityScopedResource(at: bookmarkedURL) { url in
    let data = try Data(contentsOf: url)
    // Process data
}
```

## File Access Patterns

### Open Panel

```swift
func selectFile() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.png, .jpeg]
    
    guard panel.runModal() == .OK else { return nil }
    return panel.url
}

// With bookmark
func selectAndBookmarkFile() -> URL? {
    guard let url = selectFile() else { return nil }
    try? BookmarkManager().saveBookmark(for: url)
    return url
}
```

### Save Panel

```swift
func saveFile(data: Data, suggestedName: String) -> Bool {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggestedName
    panel.allowedContentTypes = [.png]
    panel.canCreateDirectories = true
    
    guard panel.runModal() == .OK, let url = panel.url else { return false }
    
    do {
        try data.write(to: url)
        return true
    } catch {
        print("Save failed: \(error)")
        return false
    }
}
```

## Container Directories

```swift
class ContainerPaths {
    static let applicationSupport: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "App")
    }()
    
    static let caches: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "App")
    }()
    
    static let documents: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }()
    
    static let temporary: URL = {
        FileManager.default.temporaryDirectory
    }()
    
    static func ensureDirectoriesExist() throws {
        let directories = [applicationSupport, caches]
        for directory in directories {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
```

## App Groups

For sharing data between apps/extensions:

```xml
<!-- Entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>$(TeamIdentifierPrefix)com.example.shared</string>
</array>
```

```swift
class SharedContainer {
    static let shared = SharedContainer()
    
    let containerURL: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "com.example.shared")
    }()
    
    let userDefaults: UserDefaults? = {
        UserDefaults(suiteName: "com.example.shared")
    }()
}
```

## Keychain Access

```swift
import Security

class KeychainManager {
    static func save(password: String, for account: String) throws {
        let data = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    static func load(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.loadFailed(status)
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
}
```
