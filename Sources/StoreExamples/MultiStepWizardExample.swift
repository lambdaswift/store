import SwiftUI
import Store

// MARK: - Models

public enum WizardStep: Int, CaseIterable, Sendable {
    case personalInfo = 0
    case contactDetails = 1
    case preferences = 2
    case review = 3
    
    var title: String {
        switch self {
        case .personalInfo: return "Personal Information"
        case .contactDetails: return "Contact Details"
        case .preferences: return "Preferences"
        case .review: return "Review & Submit"
        }
    }
    
    var icon: String {
        switch self {
        case .personalInfo: return "person.circle"
        case .contactDetails: return "envelope.circle"
        case .preferences: return "gearshape.circle"
        case .review: return "checkmark.circle"
        }
    }
}

// MARK: - State & Actions

public struct MultiStepWizardState: Equatable, Sendable {
    // Current step
    public var currentStep: WizardStep
    public var completedSteps: Set<WizardStep>
    
    // Personal Info
    public var firstName: String
    public var lastName: String
    public var dateOfBirth: Date
    
    // Contact Details
    public var email: String
    public var phone: String
    public var address: String
    public var city: String
    public var zipCode: String
    
    // Preferences
    public var newsletter: Bool
    public var notifications: Bool
    public var marketingEmails: Bool
    public var preferredLanguage: String
    
    // Validation errors
    public var personalInfoErrors: [String: String]
    public var contactDetailsErrors: [String: String]
    public var preferencesErrors: [String: String]
    
    // Submission state
    public var isSubmitting: Bool
    public var submissionComplete: Bool
    public var submissionError: String?
    
    // Computed properties
    public var progress: Double {
        Double(completedSteps.count) / Double(WizardStep.allCases.count - 1) // -1 for review step
    }
    
    public var canProceed: Bool {
        switch currentStep {
        case .personalInfo:
            return personalInfoErrors.isEmpty && !firstName.isEmpty && !lastName.isEmpty
        case .contactDetails:
            return contactDetailsErrors.isEmpty && !email.isEmpty && !phone.isEmpty && !address.isEmpty && !city.isEmpty && !zipCode.isEmpty
        case .preferences:
            return preferencesErrors.isEmpty && !preferredLanguage.isEmpty
        case .review:
            return completedSteps.count == 3 // All previous steps completed
        }
    }
    
    public var canGoBack: Bool {
        currentStep.rawValue > 0
    }
    
    public var canGoNext: Bool {
        currentStep.rawValue < WizardStep.allCases.count - 1
    }
    
    public init() {
        self.currentStep = .personalInfo
        self.completedSteps = []
        
        // Personal Info
        self.firstName = ""
        self.lastName = ""
        self.dateOfBirth = Date().addingTimeInterval(-18 * 365 * 24 * 60 * 60) // 18 years ago
        
        // Contact Details
        self.email = ""
        self.phone = ""
        self.address = ""
        self.city = ""
        self.zipCode = ""
        
        // Preferences
        self.newsletter = false
        self.notifications = true
        self.marketingEmails = false
        self.preferredLanguage = "English"
        
        // Errors
        self.personalInfoErrors = [:]
        self.contactDetailsErrors = [:]
        self.preferencesErrors = [:]
        
        // Submission
        self.isSubmitting = false
        self.submissionComplete = false
        self.submissionError = nil
    }
}

public enum MultiStepWizardAction: Equatable, Sendable {
    // Navigation
    case nextStep
    case previousStep
    case goToStep(WizardStep)
    
    // Personal Info
    case updateFirstName(String)
    case updateLastName(String)
    case updateDateOfBirth(Date)
    
    // Contact Details
    case updateEmail(String)
    case updatePhone(String)
    case updateAddress(String)
    case updateCity(String)
    case updateZipCode(String)
    
    // Preferences
    case toggleNewsletter
    case toggleNotifications
    case toggleMarketingEmails
    case updatePreferredLanguage(String)
    
    // Validation
    case validateCurrentStep
    
    // Submission
    case submit
    case submissionCompleted(Bool, String?)
    case reset
}

// MARK: - Reducer

public func multiStepWizardReducer(state: inout MultiStepWizardState, action: MultiStepWizardAction) {
    switch action {
    // Navigation
    case .nextStep:
        if state.canProceed && state.canGoNext {
            state.completedSteps.insert(state.currentStep)
            let nextIndex = state.currentStep.rawValue + 1
            state.currentStep = WizardStep(rawValue: nextIndex) ?? state.currentStep
        }
        
    case .previousStep:
        if state.canGoBack {
            let previousIndex = state.currentStep.rawValue - 1
            state.currentStep = WizardStep(rawValue: previousIndex) ?? state.currentStep
        }
        
    case .goToStep(let step):
        // Can only go to completed steps or the next uncompleted step
        if state.completedSteps.contains(step) || step.rawValue <= state.completedSteps.count {
            state.currentStep = step
        }
        
    // Personal Info
    case .updateFirstName(let firstName):
        state.firstName = firstName
        if firstName.isEmpty {
            state.personalInfoErrors["firstName"] = "First name is required"
        } else if firstName.count < 2 {
            state.personalInfoErrors["firstName"] = "First name must be at least 2 characters"
        } else {
            state.personalInfoErrors.removeValue(forKey: "firstName")
        }
        
    case .updateLastName(let lastName):
        state.lastName = lastName
        if lastName.isEmpty {
            state.personalInfoErrors["lastName"] = "Last name is required"
        } else if lastName.count < 2 {
            state.personalInfoErrors["lastName"] = "Last name must be at least 2 characters"
        } else {
            state.personalInfoErrors.removeValue(forKey: "lastName")
        }
        
    case .updateDateOfBirth(let date):
        state.dateOfBirth = date
        let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        if age < 18 {
            state.personalInfoErrors["dateOfBirth"] = "You must be at least 18 years old"
        } else if age > 120 {
            state.personalInfoErrors["dateOfBirth"] = "Please enter a valid date of birth"
        } else {
            state.personalInfoErrors.removeValue(forKey: "dateOfBirth")
        }
        
    // Contact Details
    case .updateEmail(let email):
        state.email = email
        if email.isEmpty {
            state.contactDetailsErrors["email"] = "Email is required"
        } else if !isValidEmail(email) {
            state.contactDetailsErrors["email"] = "Please enter a valid email"
        } else {
            state.contactDetailsErrors.removeValue(forKey: "email")
        }
        
    case .updatePhone(let phone):
        state.phone = phone
        if phone.isEmpty {
            state.contactDetailsErrors["phone"] = "Phone is required"
        } else if !isValidPhone(phone) {
            state.contactDetailsErrors["phone"] = "Please enter a valid phone number"
        } else {
            state.contactDetailsErrors.removeValue(forKey: "phone")
        }
        
    case .updateAddress(let address):
        state.address = address
        if address.isEmpty {
            state.contactDetailsErrors["address"] = "Address is required"
        } else {
            state.contactDetailsErrors.removeValue(forKey: "address")
        }
        
    case .updateCity(let city):
        state.city = city
        if city.isEmpty {
            state.contactDetailsErrors["city"] = "City is required"
        } else {
            state.contactDetailsErrors.removeValue(forKey: "city")
        }
        
    case .updateZipCode(let zipCode):
        state.zipCode = zipCode
        if zipCode.isEmpty {
            state.contactDetailsErrors["zipCode"] = "ZIP code is required"
        } else if !isValidZipCode(zipCode) {
            state.contactDetailsErrors["zipCode"] = "Please enter a valid ZIP code"
        } else {
            state.contactDetailsErrors.removeValue(forKey: "zipCode")
        }
        
    // Preferences
    case .toggleNewsletter:
        state.newsletter.toggle()
        
    case .toggleNotifications:
        state.notifications.toggle()
        
    case .toggleMarketingEmails:
        state.marketingEmails.toggle()
        
    case .updatePreferredLanguage(let language):
        state.preferredLanguage = language
        if language.isEmpty {
            state.preferencesErrors["language"] = "Please select a language"
        } else {
            state.preferencesErrors.removeValue(forKey: "language")
        }
        
    // Validation
    case .validateCurrentStep:
        switch state.currentStep {
        case .personalInfo:
            if state.firstName.isEmpty {
                state.personalInfoErrors["firstName"] = "First name is required"
            }
            if state.lastName.isEmpty {
                state.personalInfoErrors["lastName"] = "Last name is required"
            }
            
        case .contactDetails:
            if state.email.isEmpty {
                state.contactDetailsErrors["email"] = "Email is required"
            }
            if state.phone.isEmpty {
                state.contactDetailsErrors["phone"] = "Phone is required"
            }
            if state.address.isEmpty {
                state.contactDetailsErrors["address"] = "Address is required"
            }
            if state.city.isEmpty {
                state.contactDetailsErrors["city"] = "City is required"
            }
            if state.zipCode.isEmpty {
                state.contactDetailsErrors["zipCode"] = "ZIP code is required"
            }
            
        case .preferences:
            if state.preferredLanguage.isEmpty {
                state.preferencesErrors["language"] = "Please select a language"
            }
            
        case .review:
            break
        }
        
    // Submission
    case .submit:
        if state.canProceed && state.currentStep == .review {
            state.isSubmitting = true
            state.submissionError = nil
        }
        
    case .submissionCompleted(let success, let error):
        state.isSubmitting = false
        if success {
            state.submissionComplete = true
        } else {
            state.submissionError = error ?? "Submission failed"
        }
        
    case .reset:
        state = MultiStepWizardState()
    }
}

// MARK: - Validation Helpers

private func isValidEmail(_ email: String) -> Bool {
    let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
}

private func isValidPhone(_ phone: String) -> Bool {
    let phoneRegex = #"^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{4,6}$"#
    let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
    return phonePredicate.evaluate(with: phone)
}

private func isValidZipCode(_ zipCode: String) -> Bool {
    let zipRegex = #"^\d{5}(-\d{4})?$"#
    let zipPredicate = NSPredicate(format: "SELF MATCHES %@", zipRegex)
    return zipPredicate.evaluate(with: zipCode)
}

// MARK: - Effects

public func multiStepWizardEffects(
    action: MultiStepWizardAction,
    state: MultiStepWizardState
) async -> MultiStepWizardAction? {
    switch action {
    case .submit:
        // Simulate submission
        do {
            try await Task.sleep(for: .seconds(2))
            let success = Double.random(in: 0...1) > 0.1
            return .submissionCompleted(
                success,
                success ? nil : "Network error. Please try again."
            )
        } catch {
            return .submissionCompleted(false, "Submission cancelled")
        }
        
    default:
        return nil
    }
}

// MARK: - Store Creation

@MainActor
public func createMultiStepWizardStore() -> Store<MultiStepWizardState, MultiStepWizardAction> {
    Store(
        initialState: MultiStepWizardState(),
        reducer: multiStepWizardReducer,
        effects: [multiStepWizardEffects]
    )
}

// MARK: - SwiftUI Views

public struct MultiStepWizardView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    public init(store: Store<MultiStepWizardState, MultiStepWizardAction>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Progress and Steps
            WizardProgressView(store: store)
                .padding()
            
            Divider()
            
            // Current Step Content
            ScrollView {
                VStack(spacing: 20) {
                    switch store.currentState.currentStep {
                    case .personalInfo:
                        PersonalInfoStepView(store: store)
                    case .contactDetails:
                        ContactDetailsStepView(store: store)
                    case .preferences:
                        PreferencesStepView(store: store)
                    case .review:
                        ReviewStepView(store: store)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Navigation Buttons
            WizardNavigationView(store: store)
                .padding()
        }
        .frame(maxWidth: 600)
        .sheet(isPresented: .constant(store.currentState.submissionComplete)) {
            SubmissionCompleteView(store: store)
        }
    }
}

struct WizardProgressView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * store.currentState.progress, height: 4)
                        .animation(.easeInOut, value: store.currentState.progress)
                }
            }
            .frame(height: 4)
            
            // Step Indicators
            HStack(spacing: 0) {
                ForEach(WizardStep.allCases, id: \.self) { step in
                    StepIndicator(
                        step: step,
                        isActive: store.currentState.currentStep == step,
                        isCompleted: store.currentState.completedSteps.contains(step),
                        store: store
                    )
                    
                    if step != WizardStep.allCases.last {
                        Spacer()
                    }
                }
            }
        }
    }
}

struct StepIndicator: View {
    let step: WizardStep
    let isActive: Bool
    let isCompleted: Bool
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        Button(action: {
            Task { await store.dispatch(.goToStep(step)) }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.blue : (isCompleted ? Color.green : Color.gray.opacity(0.3)))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isCompleted ? "checkmark" : step.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                Text(step.title)
                    .font(.caption)
                    .foregroundColor(isActive ? .blue : (isCompleted ? .green : .gray))
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isCompleted && step.rawValue > store.currentState.completedSteps.count)
    }
}

struct PersonalInfoStepView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Personal Information")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("First Name")
                    .font(.headline)
                TextField("Enter your first name", text: .init(
                    get: { store.currentState.firstName },
                    set: { newValue in Task { await store.dispatch(.updateFirstName(newValue)) } }
                ))
                .textFieldStyle(.roundedBorder)
                
                if let error = store.currentState.personalInfoErrors["firstName"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Last Name")
                    .font(.headline)
                TextField("Enter your last name", text: .init(
                    get: { store.currentState.lastName },
                    set: { newValue in Task { await store.dispatch(.updateLastName(newValue)) } }
                ))
                .textFieldStyle(.roundedBorder)
                
                if let error = store.currentState.personalInfoErrors["lastName"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Date of Birth")
                    .font(.headline)
                DatePicker("", selection: .init(
                    get: { store.currentState.dateOfBirth },
                    set: { newValue in Task { await store.dispatch(.updateDateOfBirth(newValue)) } }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
                
                if let error = store.currentState.personalInfoErrors["dateOfBirth"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct ContactDetailsStepView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Contact Details")
                .font(.title2)
                .fontWeight(.bold)
            
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
                
                if let error = store.currentState.contactDetailsErrors["email"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Phone")
                    .font(.headline)
                TextField("Enter your phone number", text: .init(
                    get: { store.currentState.phone },
                    set: { newValue in Task { await store.dispatch(.updatePhone(newValue)) } }
                ))
                .textFieldStyle(.roundedBorder)
                #if !os(macOS)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                #endif
                
                if let error = store.currentState.contactDetailsErrors["phone"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Address")
                    .font(.headline)
                TextField("Enter your address", text: .init(
                    get: { store.currentState.address },
                    set: { newValue in Task { await store.dispatch(.updateAddress(newValue)) } }
                ))
                .textFieldStyle(.roundedBorder)
                #if !os(macOS)
                .textContentType(.streetAddressLine1)
                #endif
                
                if let error = store.currentState.contactDetailsErrors["address"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("City")
                        .font(.headline)
                    TextField("Enter your city", text: .init(
                        get: { store.currentState.city },
                        set: { newValue in Task { await store.dispatch(.updateCity(newValue)) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    #if !os(macOS)
                    .textContentType(.addressCity)
                    #endif
                    
                    if let error = store.currentState.contactDetailsErrors["city"] {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ZIP Code")
                        .font(.headline)
                    TextField("Enter ZIP code", text: .init(
                        get: { store.currentState.zipCode },
                        set: { newValue in Task { await store.dispatch(.updateZipCode(newValue)) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    #if !os(macOS)
                    .keyboardType(.numberPad)
                    .textContentType(.postalCode)
                    #endif
                    
                    if let error = store.currentState.contactDetailsErrors["zipCode"] {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct PreferencesStepView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    let languages = ["English", "Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: .init(
                    get: { store.currentState.newsletter },
                    set: { _ in Task { await store.dispatch(.toggleNewsletter) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("Newsletter")
                            .font(.headline)
                        Text("Receive our weekly newsletter with updates and tips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: .init(
                    get: { store.currentState.notifications },
                    set: { _ in Task { await store.dispatch(.toggleNotifications) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("Push Notifications")
                            .font(.headline)
                        Text("Get notified about important updates and alerts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: .init(
                    get: { store.currentState.marketingEmails },
                    set: { _ in Task { await store.dispatch(.toggleMarketingEmails) } }
                )) {
                    VStack(alignment: .leading) {
                        Text("Marketing Emails")
                            .font(.headline)
                        Text("Receive promotional offers and special deals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferred Language")
                    .font(.headline)
                
                Picker("Language", selection: .init(
                    get: { store.currentState.preferredLanguage },
                    set: { newValue in Task { await store.dispatch(.updatePreferredLanguage(newValue)) } }
                )) {
                    ForEach(languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(.menu)
                
                if let error = store.currentState.preferencesErrors["language"] {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct ReviewStepView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Review Your Information")
                .font(.title2)
                .fontWeight(.bold)
            
            // Personal Info Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Personal Information")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        Task { await store.dispatch(.goToStep(.personalInfo)) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ReviewRow(label: "Name", value: "\(store.currentState.firstName) \(store.currentState.lastName)")
                    ReviewRow(label: "Date of Birth", value: store.currentState.dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Contact Details Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Contact Details")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        Task { await store.dispatch(.goToStep(.contactDetails)) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ReviewRow(label: "Email", value: store.currentState.email)
                    ReviewRow(label: "Phone", value: store.currentState.phone)
                    ReviewRow(label: "Address", value: store.currentState.address)
                    ReviewRow(label: "City/ZIP", value: "\(store.currentState.city), \(store.currentState.zipCode)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Preferences Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Preferences")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        Task { await store.dispatch(.goToStep(.preferences)) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ReviewRow(label: "Newsletter", value: store.currentState.newsletter ? "Yes" : "No")
                    ReviewRow(label: "Notifications", value: store.currentState.notifications ? "Yes" : "No")
                    ReviewRow(label: "Marketing", value: store.currentState.marketingEmails ? "Yes" : "No")
                    ReviewRow(label: "Language", value: store.currentState.preferredLanguage)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let error = store.currentState.submissionError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct WizardNavigationView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        HStack {
            Button(action: {
                Task { await store.dispatch(.previousStep) }
            }) {
                Label("Previous", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(!store.currentState.canGoBack)
            
            Spacer()
            
            if store.currentState.currentStep == .review {
                Button(action: {
                    Task { await store.dispatch(.submit) }
                }) {
                    if store.currentState.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundColor(.white)
                    } else {
                        Label("Submit", systemImage: "checkmark.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.currentState.canProceed || store.currentState.isSubmitting)
            } else {
                Button(action: {
                    Task {
                        await store.dispatch(.validateCurrentStep)
                        if store.currentState.canProceed {
                            await store.dispatch(.nextStep)
                        }
                    }
                }) {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.currentState.canProceed)
            }
        }
    }
}

struct SubmissionCompleteView: View {
    let store: Store<MultiStepWizardState, MultiStepWizardAction>
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Submission Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Thank you for completing the registration process.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start Over") {
                Task { await store.dispatch(.reset) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 400)
    }
}

// MARK: - Preview

#Preview("Multi-Step Wizard") {
    MultiStepWizardView(store: createMultiStepWizardStore())
}