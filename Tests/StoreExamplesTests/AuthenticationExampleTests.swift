import Testing
@testable import StoreExamples
import Dependencies
import Foundation

@Suite("Authentication Example Tests")
struct AuthenticationExampleTests {
    
    @Test("Initial state")
    func initialState() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            await #expect(example.store.currentState.authState == .loggedOut)
            await #expect(example.store.currentState.email == "")
            await #expect(example.store.currentState.password == "")
            await #expect(example.store.currentState.accessToken == nil)
            await #expect(example.store.currentState.refreshToken == nil)
            await #expect(example.store.currentState.isLoading == false)
            await #expect(example.store.currentState.error == nil)
        }
    }
    
    @Test("Set email")
    func setEmail() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.setEmail("test@example.com"))
            
            await #expect(example.store.currentState.email == "test@example.com")
            await #expect(example.store.currentState.error == nil)
        }
    }
    
    @Test("Set password")
    func setPassword() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.setPassword("secret123"))
            
            await #expect(example.store.currentState.password == "secret123")
            await #expect(example.store.currentState.error == nil)
        }
    }
    
    @Test("Successful login")
    func successfulLogin() async {
        let mockAuth = MockAuthService()
        let mockKeychain = MockKeychainService()
        
        await withDependencies {
            $0.authService = mockAuth
            $0.keychainService = mockKeychain
            $0.date = Date.constant(Date(timeIntervalSinceReferenceDate: 0))
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.setEmail("user@example.com"))
            await example.store.dispatch(.setPassword("password123"))
            await example.store.dispatch(.login)
            
            await example.store.waitForEffects()
            
            await #expect(example.store.currentState.authState == .loggedIn(userEmail: "user@example.com"))
            await #expect(example.store.currentState.accessToken != nil)
            await #expect(example.store.currentState.refreshToken != nil)
            await #expect(example.store.currentState.tokenExpiresAt != nil)
            await #expect(example.store.currentState.password == "")
            await #expect(example.store.currentState.isLoading == false)
            
            let storedAccessToken = try? await mockKeychain.retrieve(key: "accessToken")
            let storedRefreshToken = try? await mockKeychain.retrieve(key: "refreshToken")
            #expect(storedAccessToken != nil)
            #expect(storedRefreshToken != nil)
        }
    }
    
    @Test("Failed login with invalid credentials")
    func failedLogin() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.setEmail("wrong@example.com"))
            await example.store.dispatch(.setPassword("wrongpassword"))
            await example.store.dispatch(.login)
            
            await example.store.waitForEffects()
            
            await #expect(example.store.currentState.authState == .loggedOut)
            await #expect(example.store.currentState.error == "Invalid email or password")
            await #expect(example.store.currentState.isLoading == false)
        }
    }
    
    @Test("Login with empty fields")
    func loginEmptyFields() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.login)
            
            await #expect(example.store.currentState.error == "Please enter email and password")
            await #expect(example.store.currentState.authState == .loggedOut)
        }
    }
    
    @Test("Logout")
    func logout() async {
        let mockKeychain = MockKeychainService()
        
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = mockKeychain
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.setEmail("user@example.com"))
            await example.store.dispatch(.setPassword("password123"))
            await example.store.dispatch(.login)
            
            await example.store.waitForEffects()
            
            await example.store.dispatch(.logout)
            
            await example.store.waitForEffects()
            
            await #expect(example.store.currentState.authState == .loggedOut)
            await #expect(example.store.currentState.accessToken == nil)
            await #expect(example.store.currentState.refreshToken == nil)
            await #expect(example.store.currentState.email == "")
            await #expect(example.store.currentState.password == "")
            
            let storedAccessToken = try? await mockKeychain.retrieve(key: "accessToken")
            let storedRefreshToken = try? await mockKeychain.retrieve(key: "refreshToken")
            #expect(storedAccessToken == nil)
            #expect(storedRefreshToken == nil)
        }
    }
    
    @Test("Successful token refresh")
    func successfulTokenRefresh() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
            $0.date = Date.constant(Date(timeIntervalSinceReferenceDate: 0))
        } operation: {
            let example = await AuthenticationExample()
            
            await example.store.dispatch(.setEmail("user@example.com"))
            await example.store.dispatch(.setPassword("password123"))
            await example.store.dispatch(.login)
            
            await example.store.waitForEffects()
            
            let oldAccessToken = await example.store.currentState.accessToken
            
            await example.store.dispatch(.refreshToken)
            
            await example.store.waitForEffects()
            
            await #expect(example.store.currentState.accessToken != oldAccessToken)
            await #expect(example.store.currentState.accessToken != nil)
            await #expect(example.store.currentState.tokenExpiresAt != nil)
        }
    }
    
    @Test("Failed token refresh")
    func failedTokenRefresh() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            // Set up the state with an invalid token
            await example.store.dispatch(.loadStoredTokens(refreshToken: "invalid_token"))
            await example.store.dispatch(.setEmail("user@example.com"))
            
            await example.store.waitForEffects()
            
            await #expect(example.store.currentState.authState == .loggedOut)
            await #expect(example.store.currentState.error == "Session expired. Please login again.")
            await #expect(example.store.currentState.accessToken == nil)
            await #expect(example.store.currentState.refreshToken == nil)
        }
    }
    
    @Test("Check token expiry triggers refresh")
    func checkTokenExpiry() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
            $0.date = Date.constant(Date(timeIntervalSinceReferenceDate: 0))
        } operation: {
            let example = await AuthenticationExample()
            
            // Login first to get a valid state
            await example.store.dispatch(.setEmail("user@example.com"))
            await example.store.dispatch(.setPassword("password123"))
            await example.store.dispatch(.login)
            await example.store.waitForEffects()
            
            // Now check token expiry
            await example.store.dispatch(.checkTokenExpiry)
            await example.store.waitForEffects()
            
            await #expect(example.store.currentState.accessToken != nil)
            await #expect(example.store.currentState.authState == .loggedIn(userEmail: "user@example.com"))
        }
    }
    
    @Test("Toggle auto refresh")
    func toggleAutoRefresh() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            let initialState = await example.store.currentState.autoRefreshEnabled
            
            await example.store.dispatch(.toggleAutoRefresh)
            
            await #expect(example.store.currentState.autoRefreshEnabled == !initialState)
        }
    }
    
    @Test("Clear error")
    func clearError() async {
        await withDependencies {
            $0.authService = MockAuthService()
            $0.keychainService = MockKeychainService()
        } operation: {
            let example = await AuthenticationExample()
            
            // Trigger an error first
            await example.store.dispatch(.login) // This will fail because email/password are empty
            
            await #expect(example.store.currentState.error != nil)
            
            await example.store.dispatch(.clearError)
            
            await #expect(example.store.currentState.error == nil)
        }
    }
}

struct MockAuthService: AuthServiceProtocol {
    func login(email: String, password: String) async throws -> AuthenticationExample.LoginResponse {
        if email == "user@example.com" && password == "password123" {
            return AuthenticationExample.LoginResponse(
                accessToken: "mock_access_token",
                refreshToken: "mock_refresh_token",
                expiresIn: 300,
                userEmail: email
            )
        } else {
            throw AuthenticationExample.AuthError.invalidCredentials
        }
    }
    
    func refreshToken(refreshToken: String) async throws -> AuthenticationExample.RefreshResponse {
        if refreshToken.hasPrefix("mock_refresh") || refreshToken.hasPrefix("refresh_") {
            return AuthenticationExample.RefreshResponse(
                accessToken: "new_mock_access_token",
                expiresIn: 300
            )
        } else {
            throw AuthenticationExample.AuthError.refreshFailed
        }
    }
}

actor MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    
    func store(key: String, value: String) async throws {
        storage[key] = value
    }
    
    func retrieve(key: String) async throws -> String? {
        return storage[key]
    }
    
    func delete(key: String) async throws {
        storage.removeValue(forKey: key)
    }
}

extension Date {
    static func constant(_ date: Date) -> @Sendable () -> Date {
        return { date }
    }
}