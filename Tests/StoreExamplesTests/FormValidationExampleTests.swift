import Testing
import Foundation
import Dependencies
@testable import StoreExamples
@testable import Store

@Suite("Form Validation Example Tests")
struct FormValidationExampleTests {
    
    @Test("Form validation initial state")
    @MainActor
    func testInitialState() async {
        let store = createFormValidationStore()
        #expect(store.currentState.email == "")
        #expect(store.currentState.password == "")
        #expect(store.currentState.confirmPassword == "")
        #expect(store.currentState.acceptedTerms == false)
        #expect(store.currentState.emailError == nil)
        #expect(store.currentState.passwordError == nil)
        #expect(store.currentState.confirmPasswordError == nil)
        #expect(store.currentState.termsError == nil)
        #expect(store.currentState.isSubmitting == false)
        #expect(store.currentState.isSubmitted == false)
        #expect(store.currentState.isValid == false)
        #expect(store.currentState.passwordStrength == .none)
    }
    
    @Test("Email validation")
    @MainActor
    func testEmailValidation() async {
        let store = createFormValidationStore()
        
        // Invalid emails
        await store.dispatch(.updateEmail("invalid"))
        #expect(store.currentState.emailError == "Please enter a valid email address")
        
        await store.dispatch(.updateEmail("invalid@"))
        #expect(store.currentState.emailError == "Please enter a valid email address")
        
        await store.dispatch(.updateEmail("@example.com"))
        #expect(store.currentState.emailError == "Please enter a valid email address")
        
        await store.dispatch(.updateEmail("test@.com"))
        #expect(store.currentState.emailError == "Please enter a valid email address")
        
        // Valid emails
        await store.dispatch(.updateEmail("test@example.com"))
        #expect(store.currentState.emailError == nil)
        
        await store.dispatch(.updateEmail("user.name@example.co.uk"))
        #expect(store.currentState.emailError == nil)
        
        await store.dispatch(.updateEmail("test+tag@example.com"))
        #expect(store.currentState.emailError == nil)
        
        // Empty email should clear error
        await store.dispatch(.updateEmail(""))
        #expect(store.currentState.emailError == nil)
    }
    
    @Test("Password validation")
    @MainActor
    func testPasswordValidation() async {
        let store = createFormValidationStore()
        
        // Too short
        await store.dispatch(.updatePassword("Pass1!"))
        #expect(store.currentState.passwordError == "Password must be at least 8 characters")
        
        // Missing uppercase
        await store.dispatch(.updatePassword("password1!"))
        #expect(store.currentState.passwordError == "Password must contain both uppercase and lowercase letters")
        
        // Missing lowercase
        await store.dispatch(.updatePassword("PASSWORD1!"))
        #expect(store.currentState.passwordError == "Password must contain both uppercase and lowercase letters")
        
        // Missing number
        await store.dispatch(.updatePassword("Password!"))
        #expect(store.currentState.passwordError == "Password must contain at least one number")
        
        // Missing special character
        await store.dispatch(.updatePassword("Password1"))
        #expect(store.currentState.passwordError == "Password must contain at least one special character")
        
        // Valid password
        await store.dispatch(.updatePassword("Password1!"))
        #expect(store.currentState.passwordError == nil)
        
        // Another valid password
        await store.dispatch(.updatePassword("MyStr0ng@Pass"))
        #expect(store.currentState.passwordError == nil)
        
        // Empty password should clear error
        await store.dispatch(.updatePassword(""))
        #expect(store.currentState.passwordError == nil)
    }
    
    @Test("Password strength calculation")
    @MainActor
    func testPasswordStrength() async {
        let store = createFormValidationStore()
        
        // Empty password
        #expect(store.currentState.passwordStrength == .none)
        
        // Weak passwords
        await store.dispatch(.updatePassword("pass"))
        #expect(store.currentState.passwordStrength == .weak)
        
        await store.dispatch(.updatePassword("password"))
        #expect(store.currentState.passwordStrength == .weak)
        
        // Medium passwords
        await store.dispatch(.updatePassword("Password1"))
        #expect(store.currentState.passwordStrength == .medium)
        
        await store.dispatch(.updatePassword("Pass123!"))
        #expect(store.currentState.passwordStrength == .medium)
        
        // Strong passwords
        await store.dispatch(.updatePassword("MyStr0ng@Pass"))
        #expect(store.currentState.passwordStrength == .strong)
        
        await store.dispatch(.updatePassword("VeryL0ng&SecureP@ssw0rd!"))
        #expect(store.currentState.passwordStrength == .strong)
    }
    
    @Test("Confirm password validation")
    @MainActor
    func testConfirmPasswordValidation() async {
        let store = createFormValidationStore()
        
        // Set password first
        await store.dispatch(.updatePassword("Password1!"))
        
        // Non-matching confirm password
        await store.dispatch(.updateConfirmPassword("Password2!"))
        #expect(store.currentState.confirmPasswordError == "Passwords do not match")
        
        // Matching confirm password
        await store.dispatch(.updateConfirmPassword("Password1!"))
        #expect(store.currentState.confirmPasswordError == nil)
        
        // Change original password should re-validate
        await store.dispatch(.updatePassword("NewPass1!"))
        #expect(store.currentState.confirmPasswordError == "Passwords do not match")
        
        // Empty confirm password should clear error
        await store.dispatch(.updateConfirmPassword(""))
        #expect(store.currentState.confirmPasswordError == nil)
    }
    
    @Test("Terms acceptance")
    @MainActor
    func testTermsAcceptance() async {
        let store = createFormValidationStore()
        
        // Initially not accepted
        #expect(store.currentState.acceptedTerms == false)
        
        // Toggle on
        await store.dispatch(.toggleTerms)
        #expect(store.currentState.acceptedTerms == true)
        #expect(store.currentState.termsError == nil)
        
        // Toggle off
        await store.dispatch(.toggleTerms)
        #expect(store.currentState.acceptedTerms == false)
        #expect(store.currentState.termsError == "You must accept the terms and conditions")
    }
    
    @Test("Form validity")
    @MainActor
    func testFormValidity() async {
        let store = createFormValidationStore()
        
        // Initially invalid
        #expect(store.currentState.isValid == false)
        
        // Add valid email
        await store.dispatch(.updateEmail("test@example.com"))
        #expect(store.currentState.isValid == false)
        
        // Add valid password
        await store.dispatch(.updatePassword("Password1!"))
        #expect(store.currentState.isValid == false)
        
        // Add matching confirm password
        await store.dispatch(.updateConfirmPassword("Password1!"))
        #expect(store.currentState.isValid == false)
        
        // Accept terms
        await store.dispatch(.toggleTerms)
        #expect(store.currentState.isValid == true)
        
        // Make email invalid
        await store.dispatch(.updateEmail("invalid"))
        #expect(store.currentState.isValid == false)
        
        // Fix email
        await store.dispatch(.updateEmail("test@example.com"))
        #expect(store.currentState.isValid == true)
        
        // Make passwords not match
        await store.dispatch(.updateConfirmPassword("Different1!"))
        #expect(store.currentState.isValid == false)
    }
    
    @Test("Form submission validation")
    @MainActor
    func testFormSubmissionValidation() async {
        let store = createFormValidationStore()
        
        // Submit with empty form
        await store.dispatch(.submit)
        #expect(store.currentState.emailError == "Email is required")
        #expect(store.currentState.passwordError == "Password is required")
        #expect(store.currentState.confirmPasswordError == "Please confirm your password")
        #expect(store.currentState.termsError == "You must accept the terms and conditions")
        #expect(store.currentState.isSubmitting == false)
        
        // Submit with partial form
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePassword("Password1!"))
        await store.dispatch(.submit)
        #expect(store.currentState.emailError == nil)
        #expect(store.currentState.passwordError == nil)
        #expect(store.currentState.confirmPasswordError == "Please confirm your password")
        #expect(store.currentState.termsError == "You must accept the terms and conditions")
        #expect(store.currentState.isSubmitting == false)
    }
    
    @Test("Successful form submission")
    func testSuccessfulFormSubmission() async throws {
        await withDependencies {
            $0.formSubmission.submit = { _, _ in
                try await Task.sleep(for: .milliseconds(100))
                return true
            }
        } operation: { @MainActor in
            let store = createFormValidationStore()
            
            // Fill in valid form
            await store.dispatch(.updateEmail("test@example.com"))
            await store.dispatch(.updatePassword("Password1!"))
            await store.dispatch(.updateConfirmPassword("Password1!"))
            await store.dispatch(.toggleTerms)
            
            // Submit
            await store.dispatch(.submit)
            #expect(store.currentState.isSubmitting == true)
            
            // Wait for submission to complete
            await store.waitForEffects()
            
            #expect(store.currentState.isSubmitting == false)
            #expect(store.currentState.isSubmitted == true)
        }
    }
    
    @Test("Failed form submission")
    func testFailedFormSubmission() async throws {
        await withDependencies {
            $0.formSubmission.submit = { _, _ in
                try await Task.sleep(for: .milliseconds(100))
                return false
            }
        } operation: { @MainActor in
            let store = createFormValidationStore()
            
            // Fill in valid form
            await store.dispatch(.updateEmail("test@example.com"))
            await store.dispatch(.updatePassword("Password1!"))
            await store.dispatch(.updateConfirmPassword("Password1!"))
            await store.dispatch(.toggleTerms)
            
            // Submit
            await store.dispatch(.submit)
            await store.waitForEffects()
            
            #expect(store.currentState.isSubmitting == false)
            #expect(store.currentState.isSubmitted == false)
        }
    }
    
    @Test("Form reset")
    @MainActor
    func testFormReset() async {
        let store = createFormValidationStore()
        
        // Fill in form
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePassword("Password1!"))
        await store.dispatch(.updateConfirmPassword("Password1!"))
        await store.dispatch(.toggleTerms)
        
        // Reset
        await store.dispatch(.reset)
        
        // Check all fields are reset
        #expect(store.currentState.email == "")
        #expect(store.currentState.password == "")
        #expect(store.currentState.confirmPassword == "")
        #expect(store.currentState.acceptedTerms == false)
        #expect(store.currentState.emailError == nil)
        #expect(store.currentState.passwordError == nil)
        #expect(store.currentState.confirmPasswordError == nil)
        #expect(store.currentState.termsError == nil)
        #expect(store.currentState.isSubmitting == false)
        #expect(store.currentState.isSubmitted == false)
    }
    
    @Test("Validate actions")
    @MainActor
    func testValidateActions() async {
        let store = createFormValidationStore()
        
        // Validate empty email
        await store.dispatch(.validateEmail)
        #expect(store.currentState.emailError == "Email is required")
        
        // Validate empty password
        await store.dispatch(.validatePassword)
        #expect(store.currentState.passwordError == "Password is required")
        
        // Validate empty confirm password
        await store.dispatch(.validateConfirmPassword)
        #expect(store.currentState.confirmPasswordError == "Please confirm your password")
        
        // Validate terms not accepted
        await store.dispatch(.validateTerms)
        #expect(store.currentState.termsError == "You must accept the terms and conditions")
        
        // Add values and validate again
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.validateEmail)
        #expect(store.currentState.emailError == nil)
        
        await store.dispatch(.updatePassword("Password1!"))
        await store.dispatch(.validatePassword)
        #expect(store.currentState.passwordError == nil)
    }
    
    @Test("Reducer directly")
    func testReducerDirectly() {
        var state = FormValidationState()
        
        // Update email
        formValidationReducer(state: &state, action: .updateEmail("test@example.com"))
        #expect(state.email == "test@example.com")
        #expect(state.emailError == nil)
        
        // Update with invalid email
        formValidationReducer(state: &state, action: .updateEmail("invalid"))
        #expect(state.email == "invalid")
        #expect(state.emailError == "Please enter a valid email address")
        
        // Toggle terms
        formValidationReducer(state: &state, action: .toggleTerms)
        #expect(state.acceptedTerms == true)
        #expect(state.termsError == nil)
    }
}