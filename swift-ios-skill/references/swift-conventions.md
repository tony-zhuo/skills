# Swift Conventions for iOS

## Naming Conventions

### Types and Protocols

```swift
// Types: UpperCamelCase
struct UserProfile { }
class NetworkManager { }
enum PaymentStatus { }

// Protocols: UpperCamelCase, noun or -able/-ible suffix
protocol Identifiable { }
protocol DataFetching { }
protocol Configurable { }

// Protocol for delegates: TypeNameDelegate
protocol TableViewDelegate { }
```

### Properties and Methods

```swift
// Properties/Methods: lowerCamelCase
var userName: String
func fetchUserData() async throws -> User

// Boolean: use is/has/should prefix
var isLoading: Bool
var hasPermission: Bool
var shouldRefresh: Bool

// Factory methods: make prefix
static func makeDefault() -> Configuration
```

### Constants and Variables

```swift
// Constants: lowerCamelCase (not SCREAMING_SNAKE_CASE)
let maxRetryCount = 3
let defaultTimeout: TimeInterval = 30

// Type properties
static let shared = NetworkManager()
static let defaultConfiguration = Configuration()
```

## Optionals

### Safe Unwrapping

```swift
// Prefer optional binding
if let user = currentUser {
    display(user)
}

// Guard for early exit
guard let user = currentUser else {
    return
}

// Optional chaining
let name = user?.profile?.displayName

// Nil coalescing
let name = user?.name ?? "Anonymous"

// map/flatMap for transformations
let uppercased = name.map { $0.uppercased() }
```

### Avoid Force Unwrapping

```swift
// ❌ Avoid
let name = user!.name

// ✅ Prefer
guard let user = user else { return }
let name = user.name

// ✅ Exception: IBOutlets (implicitly unwrapped)
@IBOutlet weak var titleLabel: UILabel!

// ✅ Exception: Known safe (document why)
let url = URL(string: "https://api.example.com")! // Static, known valid
```

## Error Handling

### Define Custom Errors

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noConnection
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noConnection:
            return "No internet connection"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingFailed(let error):
            return "Failed to decode: \(error.localizedDescription)"
        }
    }
}
```

### Handle Errors Gracefully

```swift
// Use do-catch with specific error types
do {
    let data = try await fetchData()
    process(data)
} catch let error as NetworkError {
    handleNetworkError(error)
} catch let error as DecodingError {
    handleDecodingError(error)
} catch {
    handleUnknownError(error)
}

// Result type for async operations (pre async/await)
func fetchData(completion: @escaping (Result<Data, NetworkError>) -> Void)
```

## Memory Management (ARC)

### Reference Cycles

```swift
// ❌ Strong reference cycle
class Parent {
    var child: Child?
}
class Child {
    var parent: Parent? // Creates cycle
}

// ✅ Break cycle with weak
class Child {
    weak var parent: Parent?
}
```

### Closures

```swift
// ❌ Potential retain cycle
class ViewModel {
    var onComplete: (() -> Void)?
    
    func setup() {
        onComplete = {
            self.doSomething() // Captures self strongly
        }
    }
}

// ✅ Use weak self
class ViewModel {
    var onComplete: (() -> Void)?
    
    func setup() {
        onComplete = { [weak self] in
            self?.doSomething()
        }
    }
}

// ✅ Use unowned when guaranteed to exist
class ViewModel {
    lazy var formatter: NumberFormatter = { [unowned self] in
        let f = NumberFormatter()
        f.locale = self.locale
        return f
    }()
}
```

### When to Use weak vs unowned

| Use | When |
|-----|------|
| `weak` | Reference may become nil during lifetime |
| `unowned` | Reference will never be nil after initialization |

```swift
// weak: Delegates, closures with uncertain lifetime
weak var delegate: ViewControllerDelegate?

// unowned: Parent-child where child can't exist without parent
class Customer {
    let card: CreditCard
    init() {
        card = CreditCard(customer: self)
    }
}
class CreditCard {
    unowned let customer: Customer
}
```

## Access Control

```swift
// From most to least restrictive
private     // Same declaration only
fileprivate // Same file only
internal    // Same module (default)
public      // Other modules, no subclass/override
open        // Other modules, can subclass/override

// Best practice: Start private, expand as needed
private var internalState: State
private(set) var items: [Item] // Public read, private write
```

## Concurrency

### async/await (Preferred)

```swift
// Async function
func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// Call async function
Task {
    do {
        let user = try await fetchUser(id: "123")
        await MainActor.run {
            self.user = user
        }
    } catch {
        print(error)
    }
}

// MainActor for UI updates
@MainActor
class ViewModel: ObservableObject {
    @Published var user: User?
    
    func loadUser() async {
        user = try? await fetchUser(id: "123")
    }
}
```

### Task Groups

```swift
func fetchAllUsers(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask {
                try await self.fetchUser(id: id)
            }
        }
        
        var users: [User] = []
        for try await user in group {
            users.append(user)
        }
        return users
    }
}
```

## Extensions Organization

```swift
// MARK: - Lifecycle
extension ViewController {
    override func viewDidLoad() { }
    override func viewWillAppear(_ animated: Bool) { }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { }
}

// MARK: - Private Methods
private extension ViewController {
    func setupUI() { }
    func bindViewModel() { }
}
```
