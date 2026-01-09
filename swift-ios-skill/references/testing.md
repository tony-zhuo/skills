# iOS Testing Patterns

## XCTest Basics

### Test Structure

```swift
import XCTest
@testable import MyApp

final class UserViewModelTests: XCTestCase {
    
    private var sut: UserViewModel!  // System Under Test
    private var mockService: MockUserService!
    
    override func setUp() {
        super.setUp()
        mockService = MockUserService()
        sut = UserViewModel(userService: mockService)
    }
    
    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }
    
    func test_loadUser_success_updatesUser() async {
        // Given
        let expectedUser = User(id: "1", name: "John")
        mockService.mockUser = expectedUser
        
        // When
        await sut.loadUser(id: "1")
        
        // Then
        XCTAssertEqual(sut.user, expectedUser)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }
    
    func test_loadUser_failure_setsError() async {
        // Given
        mockService.shouldThrow = true
        
        // When
        await sut.loadUser(id: "1")
        
        // Then
        XCTAssertNil(sut.user)
        XCTAssertNotNil(sut.error)
    }
}
```

### Naming Conventions

```swift
// Pattern: test_<method>_<scenario>_<expectedBehavior>

func test_login_withValidCredentials_returnsUser() { }
func test_login_withInvalidPassword_throwsError() { }
func test_fetchItems_whenNetworkFails_showsError() { }
func test_addToCart_withExistingItem_incrementsQuantity() { }
```

## Async Testing

### Testing async Functions

```swift
func test_fetchData_returnsExpectedData() async throws {
    // Given
    let expectedData = TestData.sample
    mockService.mockData = expectedData
    
    // When
    let result = try await sut.fetchData()
    
    // Then
    XCTAssertEqual(result, expectedData)
}

func test_fetchData_throwsOnNetworkError() async {
    // Given
    mockService.shouldThrow = true
    
    // When/Then
    do {
        _ = try await sut.fetchData()
        XCTFail("Expected error to be thrown")
    } catch {
        XCTAssertTrue(error is NetworkError)
    }
}
```

### Testing @Published Properties

```swift
import Combine

func test_viewModel_publishesUpdates() async {
    // Given
    var receivedValues: [String] = []
    let expectation = expectation(description: "Received values")
    expectation.expectedFulfillmentCount = 2
    
    let cancellable = sut.$title
        .dropFirst() // Skip initial value
        .sink { value in
            receivedValues.append(value)
            expectation.fulfill()
        }
    
    // When
    await sut.updateTitle("First")
    await sut.updateTitle("Second")
    
    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedValues, ["First", "Second"])
    
    cancellable.cancel()
}
```

## Mocking

### Mock Protocol Implementation

```swift
protocol UserServiceProtocol {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

final class MockUserService: UserServiceProtocol {
    // Configurable responses
    var mockUser: User?
    var shouldThrow = false
    var thrownError: Error = TestError.mock
    
    // Call tracking
    var fetchUserCallCount = 0
    var fetchUserReceivedId: String?
    var updateUserCallCount = 0
    var updateUserReceivedUser: User?
    
    func fetchUser(id: String) async throws -> User {
        fetchUserCallCount += 1
        fetchUserReceivedId = id
        
        if shouldThrow { throw thrownError }
        guard let user = mockUser else { throw TestError.notFound }
        return user
    }
    
    func updateUser(_ user: User) async throws {
        updateUserCallCount += 1
        updateUserReceivedUser = user
        
        if shouldThrow { throw thrownError }
    }
}

// Usage in tests
func test_loadUser_callsServiceWithCorrectId() async {
    // When
    await sut.loadUser(id: "123")
    
    // Then
    XCTAssertEqual(mockService.fetchUserCallCount, 1)
    XCTAssertEqual(mockService.fetchUserReceivedId, "123")
}
```

### Spy Pattern

```swift
final class SpyAnalytics: AnalyticsProtocol {
    private(set) var trackedEvents: [(name: String, properties: [String: Any])] = []
    
    func track(_ event: String, properties: [String: Any]) {
        trackedEvents.append((event, properties))
    }
    
    func hasTracked(_ event: String) -> Bool {
        trackedEvents.contains { $0.name == event }
    }
    
    func lastEvent(named: String) -> [String: Any]? {
        trackedEvents.last { $0.name == named }?.properties
    }
}
```

## Test Fixtures

### Factory Pattern

```swift
enum TestFixtures {
    static func makeUser(
        id: String = "1",
        name: String = "Test User",
        email: String = "test@example.com"
    ) -> User {
        User(id: id, name: name, email: email)
    }
    
    static func makeProduct(
        id: String = UUID().uuidString,
        name: String = "Test Product",
        price: Decimal = 9.99
    ) -> Product {
        Product(id: id, name: name, price: price)
    }
}

// Usage
func test_displayUser() {
    let user = TestFixtures.makeUser(name: "John Doe")
    // ...
}
```

### JSON Fixtures

```swift
enum JSONFixtures {
    static func load<T: Decodable>(_ filename: String) -> T {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: filename, withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(T.self, from: data)
    }
    
    static let userResponse: UserResponse = load("user_response")
    static let productsResponse: [Product] = load("products_response")
}

private class BundleToken { }
```

## UI Testing

### Basic UI Test

```swift
import XCTest

final class LoginUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func test_login_withValidCredentials_navigatesToHome() {
        // Given
        let emailField = app.textFields["email_field"]
        let passwordField = app.secureTextFields["password_field"]
        let loginButton = app.buttons["login_button"]
        
        // When
        emailField.tap()
        emailField.typeText("test@example.com")
        
        passwordField.tap()
        passwordField.typeText("password123")
        
        loginButton.tap()
        
        // Then
        let homeTitle = app.staticTexts["Welcome"]
        XCTAssertTrue(homeTitle.waitForExistence(timeout: 5))
    }
}
```

### Accessibility Identifiers

```swift
// In View code
struct LoginView: View {
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .accessibilityIdentifier("email_field")
            
            SecureField("Password", text: $password)
                .accessibilityIdentifier("password_field")
            
            Button("Login") { }
                .accessibilityIdentifier("login_button")
        }
    }
}
```

### Page Object Pattern

```swift
struct LoginPage {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var emailField: XCUIElement {
        app.textFields["email_field"]
    }
    
    var passwordField: XCUIElement {
        app.secureTextFields["password_field"]
    }
    
    var loginButton: XCUIElement {
        app.buttons["login_button"]
    }
    
    @discardableResult
    func typeEmail(_ email: String) -> Self {
        emailField.tap()
        emailField.typeText(email)
        return self
    }
    
    @discardableResult
    func typePassword(_ password: String) -> Self {
        passwordField.tap()
        passwordField.typeText(password)
        return self
    }
    
    func tapLogin() -> HomePage {
        loginButton.tap()
        return HomePage(app: app)
    }
}

// Usage
func test_login_flow() {
    LoginPage(app: app)
        .typeEmail("test@example.com")
        .typePassword("password")
        .tapLogin()
        .verifyWelcomeMessage()
}
```

## Snapshot Testing

Using swift-snapshot-testing library:

```swift
import SnapshotTesting
import XCTest
@testable import MyApp

final class ProfileViewSnapshotTests: XCTestCase {
    
    func test_profileView_default() {
        let view = ProfileView(user: TestFixtures.makeUser())
        
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
    
    func test_profileView_darkMode() {
        let view = ProfileView(user: TestFixtures.makeUser())
            .environment(\.colorScheme, .dark)
        
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
    
    func test_profileView_accessibility() {
        let view = ProfileView(user: TestFixtures.makeUser())
            .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
        
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
```

## Test Organization

### Folder Structure

```
Tests/
├── UnitTests/
│   ├── ViewModels/
│   │   └── UserViewModelTests.swift
│   ├── Services/
│   │   └── APIClientTests.swift
│   └── Mocks/
│       └── MockUserService.swift
├── IntegrationTests/
│   └── DatabaseTests.swift
├── UITests/
│   ├── Pages/
│   │   └── LoginPage.swift
│   └── Flows/
│       └── LoginFlowTests.swift
└── Fixtures/
    ├── TestFixtures.swift
    └── JSON/
        └── user_response.json
```

### Test Plan

Create `MyApp.xctestplan` for organizing test execution:

```json
{
  "configurations": [
    {
      "name": "Unit Tests",
      "options": { }
    }
  ],
  "testTargets": [
    {
      "target": { "containerPath": "container:MyApp.xcodeproj", "identifier": "UnitTests" }
    },
    {
      "target": { "containerPath": "container:MyApp.xcodeproj", "identifier": "UITests" },
      "skippedTests": ["SlowTests"]
    }
  ]
}
```
