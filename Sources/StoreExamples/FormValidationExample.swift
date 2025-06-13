import SwiftUI
import Store
import Dependencies

// MARK: - State & Actions

public struct FormValidationState: Equatable, Sendable {
    public var email: String
    public var password: String
    public var confirmPassword: String
    public var acceptedTerms: Bool
    
    public var emailError: String?
    public var passwordError: String?
    public var confirmPasswordError: String?
    public var termsError: String?
    
    public var isSubmitting: Bool
    public var isSubmitted: Bool
    
    public var passwordStrength: PasswordStrength {
        calculatePasswordStrength(password)
    }
    
    public var isValid: Bool {
        emailError == nil &&
        passwordError == nil &&
        confirmPasswordError == nil &&
        termsError == nil &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        acceptedTerms
    }
    
    public init(
        email: String = "",
        password: String = "",
        confirmPassword: String = "",
        acceptedTerms: Bool = false
    ) {
        self.email = email
        self.password = password
        self.confirmPassword = confirmPassword
        self.acceptedTerms = acceptedTerms
        self.emailError = nil
        self.passwordError = nil
        self.confirmPasswordError = nil
        self.termsError = nil
        self.isSubmitting = false
        self.isSubmitted = false
    }
}

public enum PasswordStrength: Equatable, Sendable {
    case none
    case weak
    case medium
    case strong
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
    
    var text: String {
        switch self {
        case .none: return ""
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
}

public enum FormValidationAction: Equatable, Sendable {
    case updateEmail(String)
    case updatePassword(String)
    case updateConfirmPassword(String)
    case toggleTerms
    case validateEmail
    case validatePassword
    case validateConfirmPassword
    case validateTerms
    case submit
    case submitCompleted(Bool)
    case reset
}

// MARK: - Reducer

public func formValidationReducer(state: inout FormValidationState, action: FormValidationAction) {
    switch action {
    case .updateEmail(let email):
        state.email = email
        if !email.isEmpty {
            state.emailError = validateEmail(email)
        } else {
            state.emailError = nil
        }
        
    case .updatePassword(let password):
        state.password = password
        if !password.isEmpty {
            state.passwordError = validatePassword(password)
        } else {
            state.passwordError = nil
        }
        // Re-validate confirm password if it's not empty
        if !state.confirmPassword.isEmpty {
            state.confirmPasswordError = validateConfirmPassword(
                password: state.password,
                confirmPassword: state.confirmPassword
            )
        }
        
    case .updateConfirmPassword(let confirmPassword):
        state.confirmPassword = confirmPassword
        if !confirmPassword.isEmpty {
            state.confirmPasswordError = validateConfirmPassword(
                password: state.password,
                confirmPassword: confirmPassword
            )
        } else {
            state.confirmPasswordError = nil
        }
        
    case .toggleTerms:
        state.acceptedTerms.toggle()
        state.termsError = state.acceptedTerms ? nil : "You must accept the terms and conditions"
        
    case .validateEmail:
        state.emailError = state.email.isEmpty ? "Email is required" : validateEmail(state.email)
        
    case .validatePassword:
        state.passwordError = state.password.isEmpty ? "Password is required" : validatePassword(state.password)
        
    case .validateConfirmPassword:
        state.confirmPasswordError = state.confirmPassword.isEmpty 
            ? "Please confirm your password" 
            : validateConfirmPassword(password: state.password, confirmPassword: state.confirmPassword)
        
    case .validateTerms:
        state.termsError = state.acceptedTerms ? nil : "You must accept the terms and conditions"
        
    case .submit:
        // Validate all fields
        state.emailError = state.email.isEmpty ? "Email is required" : validateEmail(state.email)
        state.passwordError = state.password.isEmpty ? "Password is required" : validatePassword(state.password)
        state.confirmPasswordError = state.confirmPassword.isEmpty 
            ? "Please confirm your password" 
            : validateConfirmPassword(password: state.password, confirmPassword: state.confirmPassword)
        state.termsError = state.acceptedTerms ? nil : "You must accept the terms and conditions"
        
        if state.isValid {
            state.isSubmitting = true
        }
        
    case .submitCompleted(let success):
        state.isSubmitting = false
        state.isSubmitted = success
        
    case .reset:
        state = FormValidationState()
    }
}

// MARK: - Validation Functions

private func validateEmail(_ email: String) -> String? {
    let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    
    if !emailPredicate.evaluate(with: email) {
        return "Please enter a valid email address"
    }
    return nil
}

private func validatePassword(_ password: String) -> String? {
    if password.count < 8 {
        return "Password must be at least 8 characters"
    }
    
    let hasUppercase = password.contains { $0.isUppercase }
    let hasLowercase = password.contains { $0.isLowercase }
    let hasNumber = password.contains { $0.isNumber }
    let hasSpecialChar = password.contains { !$0.isLetter && !$0.isNumber }
    
    if !hasUppercase || !hasLowercase {
        return "Password must contain both uppercase and lowercase letters"
    }
    
    if !hasNumber {
        return "Password must contain at least one number"
    }
    
    if !hasSpecialChar {
        return "Password must contain at least one special character"
    }
    
    return nil
}

private func validateConfirmPassword(password: String, confirmPassword: String) -> String? {
    if confirmPassword != password {
        return "Passwords do not match"
    }
    return nil
}

private func calculatePasswordStrength(_ password: String) -> PasswordStrength {
    if password.isEmpty {
        return .none
    }
    
    var strength = 0
    
    // Length
    if password.count >= 8 { strength += 1 }
    if password.count >= 12 { strength += 1 }
    
    // Character variety
    let hasUppercase = password.contains { $0.isUppercase }
    let hasLowercase = password.contains { $0.isLowercase }
    let hasNumber = password.contains { $0.isNumber }
    let hasSpecialChar = password.contains { !$0.isLetter && !$0.isNumber }
    
    if hasUppercase && hasLowercase { strength += 1 }
    if hasNumber { strength += 1 }
    if hasSpecialChar { strength += 1 }
    
    switch strength {
    case 0...2: return .weak
    case 3...4: return .medium
    default: return .strong
    }
}

// MARK: - Dependencies

public struct FormSubmissionClient: DependencyKey, Sendable {
    public static let liveValue = FormSubmissionClient()
    
    public var submit: @Sendable (String, String) async throws -> Bool = { _, _ in
        try await Task.sleep(for: .seconds(2))
        return Bool.random()
    }
}

extension DependencyValues {
    public var formSubmission: FormSubmissionClient {
        get { self[FormSubmissionClient.self] }
        set { self[FormSubmissionClient.self] = newValue }
    }
}

// MARK: - Effects

public func formValidationEffects(
    action: FormValidationAction,
    state: FormValidationState
) async -> FormValidationAction? {
    @Dependency(\.formSubmission) var formSubmission
    
    switch action {
    case .submit where state.isValid:
        do {
            let success = try await formSubmission.submit(state.email, state.password)
            return .submitCompleted(success)
        } catch {
            return .submitCompleted(false)
        }
        
    default:
        return nil
    }
}

// MARK: - Store Creation

@MainActor
public func createFormValidationStore() -> Store<FormValidationState, FormValidationAction> {
    Store(
        initialState: FormValidationState(),
        reducer: formValidationReducer,
        effects: [formValidationEffects]
    )
}

// MARK: - SwiftUI View

public struct FormValidationView: View {
    let store: Store<FormValidationState, FormValidationAction>
    
    public init(store: Store<FormValidationState, FormValidationAction>) {
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.headline)
                        
                        TextField("Enter your email", text: .init(
                            get: { store.currentState.email },
                            set: { newValue in Task { await store.dispatch(.updateEmail(newValue)) } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        #if !os(macOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                        
                        if let error = store.currentState.emailError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.headline)
                        
                        SecureField("Enter your password", text: .init(
                            get: { store.currentState.password },
                            set: { newValue in Task { await store.dispatch(.updatePassword(newValue)) } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        #if !os(macOS)
                        .textContentType(.newPassword)
                        #endif
                        
                        if let error = store.currentState.passwordError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Password Strength Indicator
                        if !store.currentState.password.isEmpty {
                            HStack {
                                Text("Strength:")
                                    .font(.caption)
                                Text(store.currentState.passwordStrength.text)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(store.currentState.passwordStrength.color)
                            }
                        }
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirm Password")
                            .font(.headline)
                        
                        SecureField("Confirm your password", text: .init(
                            get: { store.currentState.confirmPassword },
                            set: { newValue in Task { await store.dispatch(.updateConfirmPassword(newValue)) } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        #if !os(macOS)
                        .textContentType(.newPassword)
                        #endif
                        
                        if let error = store.currentState.confirmPasswordError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Terms and Conditions
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button(action: {
                                Task { await store.dispatch(.toggleTerms) }
                            }) {
                                Image(systemName: store.currentState.acceptedTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(store.currentState.acceptedTerms ? .blue : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            Text("I accept the terms and conditions")
                                .font(.body)
                        }
                        
                        if let error = store.currentState.termsError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Submit Button
                Button(action: {
                    Task { await store.dispatch(.submit) }
                }) {
                    if store.currentState.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundColor(.white)
                    } else {
                        Text("Sign Up")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(store.currentState.isValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(store.currentState.isSubmitting)
                
                // Success/Error Message
                if store.currentState.isSubmitted {
                    Text("Registration successful! 🎉")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Reset Button
                if store.currentState.isSubmitted {
                    Button("Start Over") {
                        Task { await store.dispatch(.reset) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(maxWidth: 500)
    }
}

// MARK: - Preview

#Preview("Form Validation") {
    FormValidationView(store: createFormValidationStore())
}