import SwiftUI
import Store
import Dependencies

// MARK: - Models

public struct SearchResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let category: String
    public let relevanceScore: Double
    
    public init(
        id: String,
        title: String,
        description: String,
        category: String,
        relevanceScore: Double
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.relevanceScore = relevanceScore
    }
}

// MARK: - State & Actions

public struct SearchDebounceState: Equatable, Sendable {
    public var query: String
    public var results: [SearchResult]
    public var isSearching: Bool
    public var hasSearched: Bool
    public var searchError: String?
    public var selectedCategory: SearchCategory
    public var searchHistory: [String]
    public var pendingSearchId: UUID?
    
    public var filteredResults: [SearchResult] {
        guard selectedCategory != .all else { return results }
        return results.filter { $0.category == selectedCategory.rawValue }
    }
    
    public init(
        query: String = "",
        results: [SearchResult] = [],
        searchHistory: [String] = []
    ) {
        self.query = query
        self.results = results
        self.isSearching = false
        self.hasSearched = false
        self.searchError = nil
        self.selectedCategory = .all
        self.searchHistory = searchHistory
        self.pendingSearchId = nil
    }
}

public enum SearchCategory: String, CaseIterable, Sendable {
    case all = "All"
    case articles = "Articles"
    case products = "Products"
    case documentation = "Documentation"
    case tutorials = "Tutorials"
}

public enum SearchDebounceAction: Equatable, Sendable {
    case updateQuery(String)
    case search(id: UUID)
    case searchCompleted(results: [SearchResult], searchId: UUID)
    case searchFailed(error: String, searchId: UUID)
    case selectCategory(SearchCategory)
    case selectHistoryItem(String)
    case clearHistory
    case clearResults
    case cancelSearch
}

// MARK: - Reducer

public func searchDebounceReducer(state: inout SearchDebounceState, action: SearchDebounceAction) {
    switch action {
    case .updateQuery(let query):
        state.query = query
        if query.isEmpty {
            state.results = []
            state.hasSearched = false
            state.searchError = nil
            state.isSearching = false
            state.pendingSearchId = nil
        } else {
            // Generate new search ID
            let searchId = UUID()
            state.pendingSearchId = searchId
            state.isSearching = true
            state.searchError = nil
        }
        
    case .search(let searchId):
        // Only process if this is still the pending search
        if state.pendingSearchId == searchId && !state.query.isEmpty {
            state.isSearching = true
        }
        
    case .searchCompleted(let results, let searchId):
        // Only update if this search is still relevant
        if state.pendingSearchId == searchId {
            state.results = results
            state.isSearching = false
            state.hasSearched = true
            state.searchError = nil
            
            // Add to history if not already present
            if !state.query.isEmpty && !state.searchHistory.contains(state.query) {
                state.searchHistory.insert(state.query, at: 0)
                // Keep only last 10 items
                if state.searchHistory.count > 10 {
                    state.searchHistory = Array(state.searchHistory.prefix(10))
                }
            }
        }
        
    case .searchFailed(let error, let searchId):
        // Only update if this search is still relevant
        if state.pendingSearchId == searchId {
            state.searchError = error
            state.isSearching = false
            state.hasSearched = true
            state.results = []
        }
        
    case .selectCategory(let category):
        state.selectedCategory = category
        
    case .selectHistoryItem(let query):
        state.query = query
        let searchId = UUID()
        state.pendingSearchId = searchId
        state.isSearching = true
        state.searchError = nil
        
    case .clearHistory:
        state.searchHistory = []
        
    case .clearResults:
        state.results = []
        state.hasSearched = false
        state.searchError = nil
        
    case .cancelSearch:
        state.isSearching = false
        state.pendingSearchId = nil
    }
}

// MARK: - Dependencies

public struct SearchClient: DependencyKey, Sendable {
    public static let liveValue = SearchClient()
    
    public var search: @Sendable (String, SearchCategory) async throws -> [SearchResult] = { query, category in
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(800))
        
        // Check for cancellation
        try Task.checkCancellation()
        
        // Simulate search results
        let words = query.lowercased().split(separator: " ")
        var results: [SearchResult] = []
        
        let categories: [SearchCategory] = category == .all 
            ? [.articles, .products, .documentation, .tutorials]
            : [category]
        
        for (index, cat) in categories.enumerated() {
            for i in 0..<3 {
                let relevance = Double.random(in: 0.5...1.0)
                results.append(SearchResult(
                    id: "\(cat.rawValue)-\(index)-\(i)",
                    title: "\(cat.rawValue): \(words.joined(separator: " ")) - Result \(i + 1)",
                    description: "Found in \(cat.rawValue.lowercased()) matching '\(query)' with relevance score of \(Int(relevance * 100))%",
                    category: cat.rawValue,
                    relevanceScore: relevance
                ))
            }
        }
        
        // Sort by relevance
        results.sort { $0.relevanceScore > $1.relevanceScore }
        
        // Simulate occasional errors
        if Double.random(in: 0...1) < 0.1 {
            throw SearchError.networkError
        }
        
        return results
    }
}

enum SearchError: Error {
    case networkError
}

extension DependencyValues {
    public var searchClient: SearchClient {
        get { self[SearchClient.self] }
        set { self[SearchClient.self] = newValue }
    }
}

// MARK: - Effects

public func searchDebounceEffects(
    action: SearchDebounceAction,
    state: SearchDebounceState
) async -> SearchDebounceAction? {
    @Dependency(\.searchClient) var searchClient
    
    switch action {
    case .updateQuery where !state.query.isEmpty:
        // Debounce: wait before searching
        guard let searchId = state.pendingSearchId else { return nil }
        
        do {
            try await Task.sleep(for: .milliseconds(500))
            
            // Check if this search is still relevant
            try Task.checkCancellation()
            
            return .search(id: searchId)
        } catch {
            return nil
        }
        
    case .search(let searchId):
        // Perform the actual search
        do {
            let results = try await searchClient.search(state.query, state.selectedCategory)
            return .searchCompleted(results: results, searchId: searchId)
        } catch {
            let errorMessage = error is SearchError 
                ? "Network error. Please try again."
                : "Search cancelled"
            return .searchFailed(error: errorMessage, searchId: searchId)
        }
        
    case .selectHistoryItem:
        // Trigger search for history item
        guard let searchId = state.pendingSearchId else { return nil }
        return .search(id: searchId)
        
    default:
        return nil
    }
}

// MARK: - Store Creation

@MainActor
public func createSearchDebounceStore(
    initialHistory: [String] = []
) -> Store<SearchDebounceState, SearchDebounceAction> {
    let store = Store(
        initialState: SearchDebounceState(searchHistory: initialHistory),
        reducer: searchDebounceReducer,
        effects: [searchDebounceEffects]
    )
    
    // Cancel pending searches when needed
    store.beforeDispatch = { action in
        switch action {
        case .updateQuery, .cancelSearch:
            store.cancelEffects()
        default:
            break
        }
    }
    
    return store
}

// MARK: - SwiftUI Views

public struct SearchDebounceView: View {
    let store: Store<SearchDebounceState, SearchDebounceAction>
    
    public init(store: Store<SearchDebounceState, SearchDebounceAction>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Header
            SearchHeaderView(store: store)
            
            Divider()
            
            // Results or History
            if store.currentState.query.isEmpty && !store.currentState.searchHistory.isEmpty {
                SearchHistoryView(store: store)
            } else {
                SearchResultsView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.systemBackground))
        #endif
    }
}

struct SearchHeaderView: View {
    let store: Store<SearchDebounceState, SearchDebounceAction>
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Search with Debounce")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search...", text: .init(
                    get: { store.currentState.query },
                    set: { newValue in Task { await store.dispatch(.updateQuery(newValue)) } }
                ))
                .textFieldStyle(.plain)
                
                if store.currentState.isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if !store.currentState.query.isEmpty {
                    Button(action: {
                        Task { 
                            await store.dispatch(.updateQuery(""))
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Category Filter
            Picker("Category", selection: .init(
                get: { store.currentState.selectedCategory },
                set: { newValue in Task { await store.dispatch(.selectCategory(newValue)) } }
            )) {
                ForEach(SearchCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            
            // Status Text
            if store.currentState.isSearching {
                Text("Searching...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let error = store.currentState.searchError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if store.currentState.hasSearched && store.currentState.results.isEmpty {
                Text("No results found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !store.currentState.results.isEmpty {
                Text("\(store.currentState.filteredResults.count) results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct SearchResultsView: View {
    let store: Store<SearchDebounceState, SearchDebounceAction>
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.currentState.filteredResults) { result in
                    SearchResultRow(result: result)
                }
            }
            .padding()
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.title)
                    .font(.headline)
                
                Spacer()
                
                Text(result.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Text(result.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Relevance:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: result.relevanceScore)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
                
                Text("\(Int(result.relevanceScore * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    var categoryColor: Color {
        switch result.category {
        case SearchCategory.articles.rawValue:
            return .blue
        case SearchCategory.products.rawValue:
            return .green
        case SearchCategory.documentation.rawValue:
            return .orange
        case SearchCategory.tutorials.rawValue:
            return .purple
        default:
            return .gray
        }
    }
}

struct SearchHistoryView: View {
    let store: Store<SearchDebounceState, SearchDebounceAction>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                
                Spacer()
                
                if !store.currentState.searchHistory.isEmpty {
                    Button("Clear") {
                        Task { await store.dispatch(.clearHistory) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(store.currentState.searchHistory, id: \.self) { query in
                        Button(action: {
                            Task { await store.dispatch(.selectHistoryItem(query)) }
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                
                                Text(query)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.left")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Search with Debounce") {
    SearchDebounceView(
        store: createSearchDebounceStore(
            initialHistory: ["SwiftUI", "Store pattern", "Async effects"]
        )
    )
}