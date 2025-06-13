import Store
import Dependencies
import Foundation

@MainActor
public final class AuthenticationExample: ObservableObject {
    @Published private(set) var store: Store<State, Action>
    
    public struct State: Equatable, Sendable {
        var authState: AuthState = .loggedOut
        var email: String = ""
        var password: String = ""
        var accessToken: String?
        var refreshToken: String?
        var tokenExpiresAt: Date?
        var isLoading: Bool = false
        var error: String?
        var autoRefreshEnabled: Bool = true
        
        enum AuthState: Equatable, Sendable {
            case loggedOut
            case loggingIn
            case loggedIn(userEmail: String)
            case refreshingToken
        }
    }
    
    public enum Action: Equatable, Sendable {
        case setEmail(String)
        case setPassword(String)
        case login
        case loginResponse(Result<LoginResponse, AuthError>)
        case logout
        case refreshToken
        case refreshTokenResponse(Result<RefreshResponse, AuthError>)
        case checkTokenExpiry
        case clearError
        case toggleAutoRefresh
        case loadStoredTokens(refreshToken: String)
    }
    
    public struct LoginResponse: Equatable, Sendable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval
        let userEmail: String
    }
    
    public struct RefreshResponse: Equatable, Sendable {
        let accessToken: String
        let expiresIn: TimeInterval
    }
    
    public enum AuthError: Error, Equatable, Sendable, LocalizedError {
        case invalidCredentials
        case networkError
        case tokenExpired
        case refreshFailed
        case unknownError
        
        public var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                return "Invalid email or password"
            case .networkError:
                return "Network connection error"
            case .tokenExpired:
                return "Session expired"
            case .refreshFailed:
                return "Failed to refresh session"
            case .unknownError:
                return "An unknown error occurred"
            }
        }
    }
    
    private var timerTask: Task<Void, Never>?
    
    public init() {
        @Dependency(\.authService) var authService
        @Dependency(\.keychainService) var keychainService
        @Dependency(\.date) var date
        
        self.store = Store(
            initialState: State(),
            reducer: { state, action in
                switch action {
                case let .setEmail(email):
                    state.email = email
                    state.error = nil
                    
                case let .setPassword(password):
                    state.password = password
                    state.error = nil
                    
                case .login:
                    guard !state.email.isEmpty, !state.password.isEmpty else {
                        state.error = "Please enter email and password"
                        return
                    }
                    
                    state.authState = .loggingIn
                    state.isLoading = true
                    state.error = nil
                    
                case let .loginResponse(.success(response)):
                    state.isLoading = false
                    state.authState = .loggedIn(userEmail: response.userEmail)
                    state.accessToken = response.accessToken
                    state.refreshToken = response.refreshToken
                    state.tokenExpiresAt = date().addingTimeInterval(response.expiresIn)
                    state.password = ""
                    
                case let .loginResponse(.failure(error)):
                    state.isLoading = false
                    state.authState = .loggedOut
                    state.error = error.localizedDescription
                    
                case .logout:
                    state.authState = .loggedOut
                    state.accessToken = nil
                    state.refreshToken = nil
                    state.tokenExpiresAt = nil
                    state.email = ""
                    state.password = ""
                    state.error = nil
                    
                case .refreshToken:
                    guard state.refreshToken != nil else {
                        return
                    }
                    state.authState = .refreshingToken
                    
                case let .refreshTokenResponse(.success(response)):
                    state.accessToken = response.accessToken
                    state.tokenExpiresAt = date().addingTimeInterval(response.expiresIn)
                    
                    // Restore logged in state after refresh
                    if case .refreshingToken = state.authState {
                        if !state.email.isEmpty {
                            state.authState = .loggedIn(userEmail: state.email)
                        } else {
                            // If we don't have email, stay logged out
                            state.authState = .loggedOut
                        }
                    }
                    
                case .refreshTokenResponse(.failure):
                    state.error = "Session expired. Please login again."
                    state.authState = .loggedOut
                    state.accessToken = nil
                    state.refreshToken = nil
                    state.tokenExpiresAt = nil
                    
                case .checkTokenExpiry:
                    break
                    
                case .clearError:
                    state.error = nil
                    
                case .toggleAutoRefresh:
                    state.autoRefreshEnabled.toggle()
                    
                case let .loadStoredTokens(refreshToken):
                    state.refreshToken = refreshToken
                }
            },
            effects: [
                { action, state in
                    switch action {
                    case .login:
                        guard !state.email.isEmpty, !state.password.isEmpty else {
                            return nil
                        }
                        
                        let email = state.email
                        let password = state.password
                        
                        do {
                            let response = try await authService.login(email: email, password: password)
                            return .loginResponse(.success(response))
                        } catch let error as AuthError {
                            return .loginResponse(.failure(error))
                        } catch {
                            return .loginResponse(.failure(.unknownError))
                        }
                        
                    case let .loginResponse(.success(response)):
                        Task {
                            try? await keychainService.store(key: "accessToken", value: response.accessToken)
                            try? await keychainService.store(key: "refreshToken", value: response.refreshToken)
                        }
                        return nil
                        
                    case .logout:
                        Task {
                            try? await keychainService.delete(key: "accessToken")
                            try? await keychainService.delete(key: "refreshToken")
                        }
                        return nil
                        
                    case .refreshToken:
                        guard let refreshToken = state.refreshToken else {
                            return .logout
                        }
                        
                        do {
                            let response = try await authService.refreshToken(refreshToken: refreshToken)
                            return .refreshTokenResponse(.success(response))
                        } catch {
                            return .refreshTokenResponse(.failure(.refreshFailed))
                        }
                        
                    case let .refreshTokenResponse(.success(response)):
                        Task {
                            try? await keychainService.store(key: "accessToken", value: response.accessToken)
                        }
                        return nil
                        
                    case .checkTokenExpiry:
                        guard state.autoRefreshEnabled,
                              let expiresAt = state.tokenExpiresAt,
                              state.refreshToken != nil else {
                            return nil
                        }
                        
                        let now = date()
                        let timeUntilExpiry = expiresAt.timeIntervalSince(now)
                        
                        if timeUntilExpiry <= 60 {
                            return .refreshToken
                        }
                        
                        return nil
                        
                    case .loadStoredTokens:
                        // Trigger refresh to validate the loaded tokens
                        return .refreshToken
                        
                    default:
                        return nil
                    }
                }
            ]
        )
        
        Task {
            await loadStoredTokens()
            startTokenExpiryMonitor()
        }
    }
    
    deinit {
        timerTask?.cancel()
    }
    
    private func loadStoredTokens() async {
        @Dependency(\.keychainService) var keychainService
        
        if let _ = try? await keychainService.retrieve(key: "accessToken"),
           let refreshToken = try? await keychainService.retrieve(key: "refreshToken") {
            // Load the stored refresh token and trigger a refresh
            await store.dispatch(.loadStoredTokens(refreshToken: refreshToken))
        }
    }
    
    private func startTokenExpiryMonitor() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if !Task.isCancelled {
                    await store.dispatch(.checkTokenExpiry)
                }
            }
        }
    }
}

// MARK: - Service Protocols

public protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthenticationExample.LoginResponse
    func refreshToken(refreshToken: String) async throws -> AuthenticationExample.RefreshResponse
}

public protocol KeychainServiceProtocol: Sendable {
    func store(key: String, value: String) async throws
    func retrieve(key: String) async throws -> String?
    func delete(key: String) async throws
}

// MARK: - Mock Implementations

public struct AuthService: AuthServiceProtocol {
    public func login(email: String, password: String) async throws -> AuthenticationExample.LoginResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if email == "user@example.com" && password == "password123" {
            return AuthenticationExample.LoginResponse(
                accessToken: "access_\(UUID().uuidString)",
                refreshToken: "refresh_\(UUID().uuidString)",
                expiresIn: 300,
                userEmail: email
            )
        } else {
            throw AuthenticationExample.AuthError.invalidCredentials
        }
    }
    
    public func refreshToken(refreshToken: String) async throws -> AuthenticationExample.RefreshResponse {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if refreshToken.hasPrefix("refresh_") {
            return AuthenticationExample.RefreshResponse(
                accessToken: "access_\(UUID().uuidString)",
                expiresIn: 300
            )
        } else {
            throw AuthenticationExample.AuthError.refreshFailed
        }
    }
}

public actor KeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    
    public init() {}
    
    public func store(key: String, value: String) async throws {
        storage[key] = value
    }
    
    public func retrieve(key: String) async throws -> String? {
        return storage[key]
    }
    
    public func delete(key: String) async throws {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Dependency Keys

private enum AuthServiceKey: DependencyKey {
    static let liveValue: any AuthServiceProtocol = AuthService()
}

private enum KeychainServiceKey: DependencyKey {
    static let liveValue: any KeychainServiceProtocol = KeychainService()
}

// MARK: - Dependency Values

extension DependencyValues {
    var authService: any AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
    
    var keychainService: any KeychainServiceProtocol {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }
}