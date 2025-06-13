import Testing
import Foundation
@testable import StoreExamples
@testable import Store

@Suite("Multi-Step Wizard Example Tests")
struct MultiStepWizardExampleTests {
    
    @Test("Multi-step wizard initial state")
    @MainActor
    func testInitialState() async {
        let store = createMultiStepWizardStore()
        #expect(store.currentState.currentStep == .personalInfo)
        #expect(store.currentState.completedSteps.isEmpty)
        #expect(store.currentState.progress == 0.0)
        #expect(store.currentState.canGoBack == false)
        #expect(store.currentState.canGoNext == true)
        #expect(store.currentState.canProceed == false) // Empty fields
        
        // Check default values
        #expect(store.currentState.firstName == "")
        #expect(store.currentState.lastName == "")
        #expect(store.currentState.email == "")
        #expect(store.currentState.phone == "")
        #expect(store.currentState.newsletter == false)
        #expect(store.currentState.notifications == true)
        #expect(store.currentState.marketingEmails == false)
        #expect(store.currentState.preferredLanguage == "English")
        
        // Check errors are empty
        #expect(store.currentState.personalInfoErrors.isEmpty)
        #expect(store.currentState.contactDetailsErrors.isEmpty)
        #expect(store.currentState.preferencesErrors.isEmpty)
    }
    
    @Test("Personal info validation")
    @MainActor
    func testPersonalInfoValidation() async {
        let store = createMultiStepWizardStore()
        
        // Test first name validation
        await store.dispatch(.updateFirstName(""))
        #expect(store.currentState.personalInfoErrors["firstName"] == "First name is required")
        
        await store.dispatch(.updateFirstName("J"))
        #expect(store.currentState.personalInfoErrors["firstName"] == "First name must be at least 2 characters")
        
        await store.dispatch(.updateFirstName("John"))
        #expect(store.currentState.personalInfoErrors["firstName"] == nil)
        
        // Test last name validation
        await store.dispatch(.updateLastName(""))
        #expect(store.currentState.personalInfoErrors["lastName"] == "Last name is required")
        
        await store.dispatch(.updateLastName("D"))
        #expect(store.currentState.personalInfoErrors["lastName"] == "Last name must be at least 2 characters")
        
        await store.dispatch(.updateLastName("Doe"))
        #expect(store.currentState.personalInfoErrors["lastName"] == nil)
        
        // Test date of birth validation
        let youngDate = Date().addingTimeInterval(-10 * 365 * 24 * 60 * 60) // 10 years ago
        await store.dispatch(.updateDateOfBirth(youngDate))
        #expect(store.currentState.personalInfoErrors["dateOfBirth"] == "You must be at least 18 years old")
        
        let validDate = Date().addingTimeInterval(-25 * 365 * 24 * 60 * 60) // 25 years ago
        await store.dispatch(.updateDateOfBirth(validDate))
        #expect(store.currentState.personalInfoErrors["dateOfBirth"] == nil)
        
        // Check canProceed
        #expect(store.currentState.canProceed == true)
    }
    
    @Test("Contact details validation")
    @MainActor
    func testContactDetailsValidation() async {
        let store = createMultiStepWizardStore()
        // Move to contact details step by completing personal info
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        
        // Test email validation
        await store.dispatch(.updateEmail(""))
        #expect(store.currentState.contactDetailsErrors["email"] == "Email is required")
        
        await store.dispatch(.updateEmail("invalid"))
        #expect(store.currentState.contactDetailsErrors["email"] == "Please enter a valid email")
        
        await store.dispatch(.updateEmail("test@example.com"))
        #expect(store.currentState.contactDetailsErrors["email"] == nil)
        
        // Test phone validation
        await store.dispatch(.updatePhone(""))
        #expect(store.currentState.contactDetailsErrors["phone"] == "Phone is required")
        
        await store.dispatch(.updatePhone("123"))
        #expect(store.currentState.contactDetailsErrors["phone"] == "Please enter a valid phone number")
        
        await store.dispatch(.updatePhone("123-456-7890"))
        #expect(store.currentState.contactDetailsErrors["phone"] == nil)
        
        // Test address validation
        await store.dispatch(.updateAddress(""))
        #expect(store.currentState.contactDetailsErrors["address"] == "Address is required")
        
        await store.dispatch(.updateAddress("123 Main St"))
        #expect(store.currentState.contactDetailsErrors["address"] == nil)
        
        // Test city validation
        await store.dispatch(.updateCity(""))
        #expect(store.currentState.contactDetailsErrors["city"] == "City is required")
        
        await store.dispatch(.updateCity("New York"))
        #expect(store.currentState.contactDetailsErrors["city"] == nil)
        
        // Test ZIP code validation
        await store.dispatch(.updateZipCode(""))
        #expect(store.currentState.contactDetailsErrors["zipCode"] == "ZIP code is required")
        
        await store.dispatch(.updateZipCode("123"))
        #expect(store.currentState.contactDetailsErrors["zipCode"] == "Please enter a valid ZIP code")
        
        await store.dispatch(.updateZipCode("12345"))
        #expect(store.currentState.contactDetailsErrors["zipCode"] == nil)
        
        await store.dispatch(.updateZipCode("12345-6789"))
        #expect(store.currentState.contactDetailsErrors["zipCode"] == nil)
        
        // Check canProceed
        #expect(store.currentState.canProceed == true)
    }
    
    @Test("Preferences validation")
    @MainActor
    func testPreferencesValidation() async {
        let store = createMultiStepWizardStore()
        // Move to preferences step by completing previous steps
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        await store.dispatch(.nextStep)
        
        // Test language validation (should have default)
        #expect(store.currentState.preferredLanguage == "English")
        #expect(store.currentState.canProceed == true)
        
        // Test empty language
        await store.dispatch(.updatePreferredLanguage(""))
        #expect(store.currentState.preferencesErrors["language"] == "Please select a language")
        #expect(store.currentState.canProceed == false)
        
        await store.dispatch(.updatePreferredLanguage("Spanish"))
        #expect(store.currentState.preferencesErrors["language"] == nil)
        #expect(store.currentState.canProceed == true)
        
        // Test toggles
        #expect(store.currentState.newsletter == false)
        await store.dispatch(.toggleNewsletter)
        #expect(store.currentState.newsletter == true)
        
        #expect(store.currentState.notifications == true)
        await store.dispatch(.toggleNotifications)
        #expect(store.currentState.notifications == false)
        
        #expect(store.currentState.marketingEmails == false)
        await store.dispatch(.toggleMarketingEmails)
        #expect(store.currentState.marketingEmails == true)
    }
    
    @Test("Navigation between steps")
    @MainActor
    func testNavigation() async {
        let store = createMultiStepWizardStore()
        
        // Fill in personal info
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        
        // Try to go next
        await store.dispatch(.nextStep)
        #expect(store.currentState.currentStep == .contactDetails)
        #expect(store.currentState.completedSteps.contains(.personalInfo))
        #expect(store.currentState.progress == 1.0/3.0)
        
        // Go back
        await store.dispatch(.previousStep)
        #expect(store.currentState.currentStep == .personalInfo)
        
        // Go forward again
        await store.dispatch(.nextStep)
        #expect(store.currentState.currentStep == .contactDetails)
        
        // Fill in contact details
        await store.dispatch(.updateEmail("john@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        
        // Go to next step
        await store.dispatch(.nextStep)
        #expect(store.currentState.currentStep == .preferences)
        #expect(store.currentState.completedSteps.contains(.contactDetails))
        #expect(store.currentState.progress == 2.0/3.0)
        
        // Go to final step
        await store.dispatch(.nextStep)
        #expect(store.currentState.currentStep == .review)
        #expect(store.currentState.completedSteps.contains(.preferences))
        #expect(store.currentState.progress == 1.0)
    }
    
    @Test("Cannot skip steps")
    @MainActor
    func testCannotSkipSteps() async {
        let store = createMultiStepWizardStore()
        
        // Try to go to step 2 without completing step 1
        await store.dispatch(.goToStep(.contactDetails))
        #expect(store.currentState.currentStep == .personalInfo)
        
        // Try to go to step 3
        await store.dispatch(.goToStep(.preferences))
        #expect(store.currentState.currentStep == .personalInfo)
        
        // Try to go to review
        await store.dispatch(.goToStep(.review))
        #expect(store.currentState.currentStep == .personalInfo)
        
        // Complete step 1
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        
        // Now can go back to step 1
        await store.dispatch(.goToStep(.personalInfo))
        #expect(store.currentState.currentStep == .personalInfo)
        
        // Can go to current step
        await store.dispatch(.goToStep(.contactDetails))
        #expect(store.currentState.currentStep == .contactDetails)
        
        // Still cannot skip ahead
        await store.dispatch(.goToStep(.review))
        #expect(store.currentState.currentStep == .contactDetails)
    }
    
    @Test("Validate current step action")
    @MainActor
    func testValidateCurrentStep() async {
        let store = createMultiStepWizardStore()
        
        // Validate empty personal info
        await store.dispatch(.validateCurrentStep)
        #expect(store.currentState.personalInfoErrors["firstName"] == "First name is required")
        #expect(store.currentState.personalInfoErrors["lastName"] == "Last name is required")
        
        // Fill and validate
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.validateCurrentStep)
        // Errors should be cleared by the update actions
        
        // Move to contact details
        await store.dispatch(.nextStep)
        
        // Validate empty contact details
        await store.dispatch(.validateCurrentStep)
        #expect(store.currentState.contactDetailsErrors["email"] == "Email is required")
        #expect(store.currentState.contactDetailsErrors["phone"] == "Phone is required")
        #expect(store.currentState.contactDetailsErrors["address"] == "Address is required")
        #expect(store.currentState.contactDetailsErrors["city"] == "City is required")
        #expect(store.currentState.contactDetailsErrors["zipCode"] == "ZIP code is required")
    }
    
    @Test("Progress calculation")
    @MainActor
    func testProgressCalculation() async {
        let store = createMultiStepWizardStore()
        
        // Initial progress
        #expect(store.currentState.progress == 0.0)
        
        // Complete step 1
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        #expect(store.currentState.progress == 1.0/3.0)
        
        // Complete step 2
        await store.dispatch(.updateEmail("john@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        await store.dispatch(.nextStep)
        #expect(store.currentState.progress == 2.0/3.0)
        
        // Complete step 3
        await store.dispatch(.nextStep)
        #expect(store.currentState.progress == 1.0)
    }
    
    @Test("Review step requires all steps completed")
    @MainActor
    func testReviewStepRequirements() async {
        let store = createMultiStepWizardStore()
        
        // Complete all steps to get to review
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        await store.dispatch(.nextStep)
        
        await store.dispatch(.nextStep) // To review
        
        #expect(store.currentState.currentStep == .review)
        #expect(store.currentState.canProceed == true)
    }
    
    @Test("Submission")
    @MainActor
    func testSubmission() async {
        let store = createMultiStepWizardStore()
        
        // Complete all steps to enable submission
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        await store.dispatch(.nextStep)
        
        await store.dispatch(.nextStep) // To review
        
        // Submit
        await store.dispatch(.submit)
        #expect(store.currentState.isSubmitting == true)
        
        // Wait for effect
        await store.waitForEffects()
        
        // Should complete (90% success rate in mock)
        #expect(store.currentState.isSubmitting == false)
        // Either success or failure
        if store.currentState.submissionComplete {
            #expect(store.currentState.submissionError == nil)
        } else {
            #expect(store.currentState.submissionError != nil)
        }
    }
    
    @Test("Cannot submit from non-review step")
    @MainActor
    func testCannotSubmitFromNonReviewStep() async {
        let store = createMultiStepWizardStore()
        
        // Try to submit from first step
        await store.dispatch(.submit)
        #expect(store.currentState.isSubmitting == false)
        
        // Move to contact details and try
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        await store.dispatch(.submit)
        #expect(store.currentState.isSubmitting == false)
        
        // Move to preferences and try
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        await store.dispatch(.nextStep)
        await store.dispatch(.submit)
        #expect(store.currentState.isSubmitting == false)
    }
    
    @Test("Reset action")
    @MainActor
    func testReset() async {
        let store = createMultiStepWizardStore()
        
        // Fill in some data and navigate
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        await store.dispatch(.nextStep)
        await store.dispatch(.updateEmail("john@example.com"))
        
        // Reset
        await store.dispatch(.reset)
        
        // Check everything is reset
        #expect(store.currentState.currentStep == .personalInfo)
        #expect(store.currentState.completedSteps.isEmpty)
        #expect(store.currentState.firstName == "")
        #expect(store.currentState.lastName == "")
        #expect(store.currentState.email == "")
        #expect(store.currentState.submissionComplete == false)
    }
    
    @Test("Navigation buttons state")
    @MainActor
    func testNavigationButtonsState() async {
        let store = createMultiStepWizardStore()
        
        // First step - can't go back
        #expect(store.currentState.canGoBack == false)
        #expect(store.currentState.canGoNext == true)
        
        // Fill required fields
        await store.dispatch(.updateFirstName("John"))
        await store.dispatch(.updateLastName("Doe"))
        
        // Move to second step
        await store.dispatch(.nextStep)
        #expect(store.currentState.canGoBack == true)
        #expect(store.currentState.canGoNext == true)
        
        // Complete all steps to get to review
        await store.dispatch(.updateEmail("test@example.com"))
        await store.dispatch(.updatePhone("123-456-7890"))
        await store.dispatch(.updateAddress("123 Main St"))
        await store.dispatch(.updateCity("New York"))
        await store.dispatch(.updateZipCode("12345"))
        await store.dispatch(.nextStep)
        await store.dispatch(.nextStep) // To review
        
        #expect(store.currentState.currentStep == .review)
        #expect(store.currentState.canGoBack == true)
        #expect(store.currentState.canGoNext == false)
    }
    
    @Test("Wizard step enum")
    func testWizardStepEnum() {
        #expect(WizardStep.personalInfo.title == "Personal Information")
        #expect(WizardStep.contactDetails.title == "Contact Details")
        #expect(WizardStep.preferences.title == "Preferences")
        #expect(WizardStep.review.title == "Review & Submit")
        
        #expect(WizardStep.personalInfo.icon == "person.circle")
        #expect(WizardStep.contactDetails.icon == "envelope.circle")
        #expect(WizardStep.preferences.icon == "gearshape.circle")
        #expect(WizardStep.review.icon == "checkmark.circle")
        
        #expect(WizardStep.allCases.count == 4)
    }
    
    @Test("Reducer directly")
    func testReducerDirectly() {
        var state = MultiStepWizardState()
        
        // Update first name
        multiStepWizardReducer(state: &state, action: .updateFirstName("John"))
        #expect(state.firstName == "John")
        #expect(state.personalInfoErrors["firstName"] == nil)
        
        // Toggle newsletter
        multiStepWizardReducer(state: &state, action: .toggleNewsletter)
        #expect(state.newsletter == true)
        
        // Navigation
        state.firstName = "John"
        state.lastName = "Doe"
        multiStepWizardReducer(state: &state, action: .nextStep)
        #expect(state.currentStep == .contactDetails)
        #expect(state.completedSteps.contains(.personalInfo))
    }
}