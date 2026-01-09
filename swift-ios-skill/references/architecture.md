# iOS Architecture Patterns

## MVVM (Model-View-ViewModel)

Recommended pattern for SwiftUI applications.

### Structure

```
Feature/
├── Models/
│   └── User.swift
├── ViewModels/
│   └── UserViewModel.swift
├── Views/
│   └── UserView.swift
└── Services/
    └── UserService.swift
```

### Implementation

```swift
// Model
struct User: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
}

// ViewModel
@MainActor
final class UserViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }
    
    func loadUser(id: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            user = try await userService.fetchUser(id: id)
        } catch {
            self.error = error
        }
    }
    
    func updateName(_ name: String) async {
        guard var user else { return }
        user = User(id: user.id, name: name, email: user.email)
        self.user = user
        
        do {
            try await userService.updateUser(user)
        } catch {
            self.error = error
        }
    }
}

// View
struct UserView: View {
    @StateObject private var viewModel = UserViewModel()
    let userId: String
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                UserContent(user: user)
            } else {
                Text("User not found")
            }
        }
        .task {
            await viewModel.loadUser(id: userId)
        }
    }
}
```

## Dependency Injection

### Protocol-Based DI

```swift
// Define protocol
protocol UserServiceProtocol {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

// Production implementation
final class UserService: UserServiceProtocol {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL = URL(string: "https://api.example.com")!,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func fetchUser(id: String) async throws -> User {
        let url = baseURL.appending(path: "users/\(id)")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    func updateUser(_ user: User) async throws {
        // Implementation
    }
}

// Mock for testing
final class MockUserService: UserServiceProtocol {
    var mockUser: User?
    var shouldThrow = false
    
    func fetchUser(id: String) async throws -> User {
        if shouldThrow { throw TestError.mock }
        guard let user = mockUser else { throw TestError.notFound }
        return user
    }
    
    func updateUser(_ user: User) async throws {
        mockUser = user
    }
}
```

### Container-Based DI

```swift
// Simple DI container
final class DIContainer {
    static let shared = DIContainer()
    
    private var services: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let service = services[key] as? T else {
            fatalError("Service \(key) not registered")
        }
        return service
    }
}

// Registration (at app startup)
DIContainer.shared.register(UserServiceProtocol.self, instance: UserService())

// Usage
class UserViewModel {
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol = DIContainer.shared.resolve(UserServiceProtocol.self)) {
        self.userService = userService
    }
}
```

### Environment-Based DI (SwiftUI)

```swift
// Define environment key
private struct UserServiceKey: EnvironmentKey {
    static let defaultValue: UserServiceProtocol = UserService()
}

extension EnvironmentValues {
    var userService: UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// Usage in views
struct UserView: View {
    @Environment(\.userService) private var userService
    
    var body: some View {
        // Use userService
    }
}

// Inject mock in previews
#Preview {
    UserView()
        .environment(\.userService, MockUserService())
}
```

## Clean Architecture

### Layer Structure

```
App/
├── Domain/           # Business logic (no external dependencies)
│   ├── Entities/
│   ├── UseCases/
│   └── Repositories/ (protocols only)
├── Data/             # Data access
│   ├── Repositories/ (implementations)
│   ├── DataSources/
│   └── DTOs/
└── Presentation/     # UI
    ├── Views/
    ├── ViewModels/
    └── Coordinators/
```

### Implementation

```swift
// Domain Layer - Entity
struct Product: Identifiable {
    let id: String
    let name: String
    let price: Decimal
}

// Domain Layer - Repository Protocol
protocol ProductRepository {
    func getProducts() async throws -> [Product]
    func getProduct(id: String) async throws -> Product
}

// Domain Layer - Use Case
protocol GetProductsUseCase {
    func execute() async throws -> [Product]
}

final class GetProductsUseCaseImpl: GetProductsUseCase {
    private let repository: ProductRepository
    
    init(repository: ProductRepository) {
        self.repository = repository
    }
    
    func execute() async throws -> [Product] {
        try await repository.getProducts()
    }
}

// Data Layer - DTO
struct ProductDTO: Codable {
    let id: String
    let name: String
    let priceInCents: Int
    
    func toDomain() -> Product {
        Product(
            id: id,
            name: name,
            price: Decimal(priceInCents) / 100
        )
    }
}

// Data Layer - Repository Implementation
final class ProductRepositoryImpl: ProductRepository {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func getProducts() async throws -> [Product] {
        let dtos: [ProductDTO] = try await apiClient.get("/products")
        return dtos.map { $0.toDomain() }
    }
    
    func getProduct(id: String) async throws -> Product {
        let dto: ProductDTO = try await apiClient.get("/products/\(id)")
        return dto.toDomain()
    }
}

// Presentation Layer - ViewModel
@MainActor
final class ProductListViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    
    private let getProductsUseCase: GetProductsUseCase
    
    init(getProductsUseCase: GetProductsUseCase) {
        self.getProductsUseCase = getProductsUseCase
    }
    
    func loadProducts() async {
        do {
            products = try await getProductsUseCase.execute()
        } catch {
            // Handle error
        }
    }
}
```

## Coordinator Pattern

For complex navigation flows.

```swift
// Coordinator protocol
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    func start()
}

// Main coordinator
final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private let window: UIWindow
    private var navigationController: UINavigationController
    
    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
    }
    
    func start() {
        let homeCoordinator = HomeCoordinator(navigationController: navigationController)
        homeCoordinator.parentCoordinator = self
        childCoordinators.append(homeCoordinator)
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        
        homeCoordinator.start()
    }
    
    func childDidFinish(_ child: Coordinator) {
        childCoordinators.removeAll { $0 === child }
    }
}

// Feature coordinator
final class HomeCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    weak var parentCoordinator: AppCoordinator?
    private let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let viewModel = HomeViewModel()
        viewModel.coordinator = self
        let viewController = HomeViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: false)
    }
    
    func showDetail(for item: Item) {
        let detailVC = DetailViewController(item: item)
        navigationController.pushViewController(detailVC, animated: true)
    }
}
```

## Module Structure

For larger apps, organize by feature module.

```
App/
├── Core/                    # Shared utilities
│   ├── Networking/
│   ├── Storage/
│   └── Extensions/
├── Features/
│   ├── Auth/
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   ├── Views/
│   │   └── Services/
│   ├── Home/
│   └── Profile/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```
