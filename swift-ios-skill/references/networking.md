# iOS Networking Patterns

## URLSession with async/await

### Basic Request

```swift
func fetchData<T: Decodable>(from url: URL) async throws -> T {
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
    }
    
    guard 200..<300 ~= httpResponse.statusCode else {
        throw NetworkError.serverError(statusCode: httpResponse.statusCode)
    }
    
    return try JSONDecoder().decode(T.self, from: data)
}
```

### API Client

```swift
protocol APIClientProtocol {
    func get<T: Decodable>(_ path: String) async throws -> T
    func post<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T
    func put<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T
    func delete(_ path: String) async throws
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        
        // Configure decoder
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        // Configure encoder
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET")
        return try await execute(request)
    }
    
    func post<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T {
        var request = try makeRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }
    
    func put<T: Decodable, U: Encodable>(_ path: String, body: U) async throws -> T {
        var request = try makeRequest(path: path, method: "PUT")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }
    
    func delete(_ path: String) async throws {
        let request = try makeRequest(path: path, method: "DELETE")
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }
    
    // MARK: - Private
    
    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(underlying: error)
        }
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 500..<600:
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw NetworkError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}
```

### Network Error Types

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noConnection
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)
    case unknown(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error (\(code))"
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unknown(let code):
            return "Unknown error (\(code))"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError:
            return true
        default:
            return false
        }
    }
}
```

## Authentication

### Token-Based Auth

```swift
actor AuthManager {
    static let shared = AuthManager()
    
    private var accessToken: String?
    private var refreshToken: String?
    private var isRefreshing = false
    
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
    }
    
    func getAccessToken() -> String? {
        accessToken
    }
    
    func refreshTokenIfNeeded() async throws {
        guard !isRefreshing else { return }
        guard let refreshToken else {
            throw AuthError.notAuthenticated
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        let response = try await AuthService.refresh(token: refreshToken)
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }
}

// Authenticated API Client
final class AuthenticatedAPIClient: APIClientProtocol {
    private let client: APIClient
    private let authManager: AuthManager
    
    init(client: APIClient, authManager: AuthManager = .shared) {
        self.client = client
        self.authManager = authManager
    }
    
    func get<T: Decodable>(_ path: String) async throws -> T {
        try await executeWithAuth {
            try await client.get(path)
        }
    }
    
    private func executeWithAuth<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch NetworkError.unauthorized {
            try await authManager.refreshTokenIfNeeded()
            return try await operation()
        }
    }
}
```

## Request Retry

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    delay: Duration = .seconds(1),
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch let error as NetworkError where error.isRetryable {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(for: delay * Double(attempt))
            }
        } catch {
            throw error
        }
    }
    
    throw lastError ?? NetworkError.unknown(statusCode: 0)
}

// Usage
let data: UserData = try await withRetry {
    try await apiClient.get("/user")
}
```

## Request Cancellation

```swift
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [SearchResult] = []
    
    private var searchTask: Task<Void, Never>?
    
    func search() {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            // Debounce
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await SearchService.search(query: query)
                
                guard !Task.isCancelled else { return }
                
                self.results = results
            } catch {
                guard !Task.isCancelled else { return }
                // Handle error
            }
        }
    }
}
```

## Multipart Upload

```swift
func uploadImage(_ image: UIImage, to path: String) async throws -> UploadResponse {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        throw UploadError.invalidImage
    }
    
    let boundary = UUID().uuidString
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    
    request.httpBody = body
    
    let (data, response) = try await session.data(for: request)
    try validateResponse(response)
    
    return try decoder.decode(UploadResponse.self, from: data)
}
```

## Download with Progress

```swift
func downloadFile(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> URL {
    let (asyncBytes, response) = try await session.bytes(from: url)
    
    let totalBytes = response.expectedContentLength
    var receivedBytes: Int64 = 0
    var data = Data()
    
    for try await byte in asyncBytes {
        data.append(byte)
        receivedBytes += 1
        
        if totalBytes > 0 {
            let progress = Double(receivedBytes) / Double(totalBytes)
            await MainActor.run {
                progressHandler(progress)
            }
        }
    }
    
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try data.write(to: tempURL)
    
    return tempURL
}
```

## Network Monitoring

```swift
import Network

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
```
