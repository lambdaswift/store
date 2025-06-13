import Testing
import Foundation
import Dependencies
@testable import StoreExamples
@testable import Store

@Suite("Search Debounce Example Tests")
struct SearchDebounceExampleTests {
    
    @Test("Search debounce initial state")
    @MainActor
    func testInitialState() async {
        let store = createSearchDebounceStore()
        #expect(store.currentState.query == "")
        #expect(store.currentState.results.isEmpty)
        #expect(store.currentState.isSearching == false)
        #expect(store.currentState.hasSearched == false)
        #expect(store.currentState.searchError == nil)
        #expect(store.currentState.selectedCategory == .all)
        #expect(store.currentState.searchHistory.isEmpty)
        #expect(store.currentState.pendingSearchId == nil)
    }
    
    @Test("Initial state with history")
    @MainActor
    func testInitialStateWithHistory() async {
        let history = ["test1", "test2", "test3"]
        let store = createSearchDebounceStore(initialHistory: history)
        #expect(store.currentState.searchHistory == history)
    }
    
    @Test("Update query triggers debounced search")
    func testUpdateQueryDebounce() async throws {
        let searchCalled = LockIsolated(false)
        let searchQuery = LockIsolated("")
        
        try await withDependencies {
            $0.searchClient.search = { query, _ in
                searchCalled.withValue { $0 = true }
                searchQuery.withValue { $0 = query }
                return [
                    SearchResult(
                        id: "1",
                        title: "Test Result",
                        description: "Test",
                        category: "Articles",
                        relevanceScore: 0.9
                    )
                ]
            }
        } operation: { @MainActor in
            let store = createSearchDebounceStore()
            
            // Update query
            await store.dispatch(.updateQuery("test query"))
            #expect(store.currentState.query == "test query")
            #expect(store.currentState.isSearching == true)
            #expect(store.currentState.pendingSearchId != nil)
            
            // Search should not be called immediately
            #expect(searchCalled.value == false)
            
            // Wait for debounce and search to complete
            try await Task.sleep(for: .milliseconds(600))
            await store.waitForEffects()
            
            // Search should have been called
            #expect(searchCalled.value == true)
            #expect(searchQuery.value == "test query")
            #expect(store.currentState.results.count == 1)
            #expect(store.currentState.isSearching == false)
            #expect(store.currentState.hasSearched == true)
        }
    }
    
    @Test("Rapid query updates")
    @MainActor
    func testRapidQueryUpdates() async throws {
        let store = createSearchDebounceStore()
        
        // Test that rapid query updates properly update state
        await store.dispatch(.updateQuery("a"))
        #expect(store.currentState.query == "a")
        #expect(store.currentState.isSearching == true)
        let firstId = store.currentState.pendingSearchId
        
        await store.dispatch(.updateQuery("ab"))
        #expect(store.currentState.query == "ab")
        #expect(store.currentState.isSearching == true)
        let secondId = store.currentState.pendingSearchId
        #expect(firstId != secondId)
        
        await store.dispatch(.updateQuery("abc"))
        #expect(store.currentState.query == "abc")
        #expect(store.currentState.isSearching == true)
        let thirdId = store.currentState.pendingSearchId
        #expect(secondId != thirdId)
        
        // Clear query
        await store.dispatch(.updateQuery(""))
        #expect(store.currentState.query == "")
        #expect(store.currentState.isSearching == false)
        #expect(store.currentState.pendingSearchId == nil)
    }
    
    @Test("Empty query clears results")
    @MainActor
    func testEmptyQueryClearsResults() async {
        // Set up some state
        var state = SearchDebounceState(
            query: "test",
            results: [
                SearchResult(
                    id: "1",
                    title: "Test",
                    description: "Test",
                    category: "Articles",
                    relevanceScore: 0.9
                )
            ]
        )
        state.hasSearched = true
        state.isSearching = false
        
        // Update to empty query
        searchDebounceReducer(state: &state, action: .updateQuery(""))
        #expect(state.query == "")
        #expect(state.results.isEmpty)
        #expect(state.hasSearched == false)
        #expect(state.searchError == nil)
        #expect(state.isSearching == false)
        #expect(state.pendingSearchId == nil)
    }
    
    @Test("Search completion updates state")
    @MainActor
    func testSearchCompletion() async {
        var state = SearchDebounceState(query: "test")
        let searchId = UUID()
        state.pendingSearchId = searchId
        state.isSearching = true
        
        let results = [
            SearchResult(
                id: "1",
                title: "Result 1",
                description: "Test",
                category: "Articles",
                relevanceScore: 0.9
            ),
            SearchResult(
                id: "2",
                title: "Result 2",
                description: "Test",
                category: "Products",
                relevanceScore: 0.8
            )
        ]
        
        searchDebounceReducer(state: &state, action: .searchCompleted(results: results, searchId: searchId))
        
        #expect(state.results == results)
        #expect(state.isSearching == false)
        #expect(state.hasSearched == true)
        #expect(state.searchError == nil)
        #expect(state.searchHistory == ["test"])
    }
    
    @Test("Search completion adds to history")
    @MainActor
    func testSearchHistory() async {
        var state = SearchDebounceState(query: "new search")
        let searchId = UUID()
        state.pendingSearchId = searchId
        state.searchHistory = ["old1", "old2"]
        
        searchDebounceReducer(state: &state, action: .searchCompleted(results: [], searchId: searchId))
        
        #expect(state.searchHistory == ["new search", "old1", "old2"])
    }
    
    @Test("Search history limited to 10 items")
    @MainActor
    func testSearchHistoryLimit() async {
        var state = SearchDebounceState(query: "new")
        let searchId = UUID()
        state.pendingSearchId = searchId
        state.searchHistory = Array(1...10).map { "search\($0)" }
        
        searchDebounceReducer(state: &state, action: .searchCompleted(results: [], searchId: searchId))
        
        #expect(state.searchHistory.count == 10)
        #expect(state.searchHistory.first == "new")
        #expect(!state.searchHistory.contains("search10"))
    }
    
    @Test("Duplicate searches not added to history")
    @MainActor
    func testNoDuplicateHistory() async {
        var state = SearchDebounceState(query: "existing")
        let searchId = UUID()
        state.pendingSearchId = searchId
        state.searchHistory = ["existing", "other"]
        
        searchDebounceReducer(state: &state, action: .searchCompleted(results: [], searchId: searchId))
        
        #expect(state.searchHistory == ["existing", "other"])
    }
    
    @Test("Search failure handling")
    @MainActor
    func testSearchFailure() async {
        var state = SearchDebounceState(query: "test")
        let searchId = UUID()
        state.pendingSearchId = searchId
        state.isSearching = true
        
        searchDebounceReducer(state: &state, action: .searchFailed(error: "Network error", searchId: searchId))
        
        #expect(state.searchError == "Network error")
        #expect(state.isSearching == false)
        #expect(state.hasSearched == true)
        #expect(state.results.isEmpty)
    }
    
    @Test("Outdated search results ignored")
    @MainActor
    func testOutdatedSearchIgnored() async {
        var state = SearchDebounceState(query: "current")
        let currentId = UUID()
        let oldId = UUID()
        state.pendingSearchId = currentId
        state.isSearching = true
        
        // Try to complete old search
        searchDebounceReducer(state: &state, action: .searchCompleted(
            results: [SearchResult(id: "1", title: "Old", description: "", category: "Articles", relevanceScore: 0.5)],
            searchId: oldId
        ))
        
        // State should not change
        #expect(state.results.isEmpty)
        #expect(state.isSearching == true)
        #expect(state.hasSearched == false)
    }
    
    @Test("Category filtering")
    @MainActor
    func testCategoryFiltering() async {
        let store = createSearchDebounceStore()
        
        // Set up results in different categories
        var state = store.currentState
        state.results = [
            SearchResult(id: "1", title: "Article 1", description: "", category: "Articles", relevanceScore: 0.9),
            SearchResult(id: "2", title: "Product 1", description: "", category: "Products", relevanceScore: 0.8),
            SearchResult(id: "3", title: "Article 2", description: "", category: "Articles", relevanceScore: 0.7),
            SearchResult(id: "4", title: "Doc 1", description: "", category: "Documentation", relevanceScore: 0.6)
        ]
        
        // All categories
        #expect(state.filteredResults.count == 4)
        
        // Filter by Articles
        state.selectedCategory = .articles
        #expect(state.filteredResults.count == 2)
        #expect(state.filteredResults.allSatisfy { $0.category == "Articles" })
        
        // Filter by Products
        state.selectedCategory = .products
        #expect(state.filteredResults.count == 1)
        #expect(state.filteredResults[0].category == "Products")
        
        // Filter by Documentation
        state.selectedCategory = .documentation
        #expect(state.filteredResults.count == 1)
        #expect(state.filteredResults[0].category == "Documentation")
        
        // Filter by Tutorials (no results)
        state.selectedCategory = .tutorials
        #expect(state.filteredResults.isEmpty)
    }
    
    @Test("Select history item")
    @MainActor
    func testSelectHistoryItem() async {
        var state = SearchDebounceState()
        state.searchHistory = ["previous search"]
        
        searchDebounceReducer(state: &state, action: .selectHistoryItem("previous search"))
        
        #expect(state.query == "previous search")
        #expect(state.isSearching == true)
        #expect(state.pendingSearchId != nil)
        #expect(state.searchError == nil)
    }
    
    @Test("Clear history")
    @MainActor
    func testClearHistory() async {
        var state = SearchDebounceState()
        state.searchHistory = ["search1", "search2", "search3"]
        
        searchDebounceReducer(state: &state, action: .clearHistory)
        
        #expect(state.searchHistory.isEmpty)
    }
    
    @Test("Clear results")
    @MainActor
    func testClearResults() async {
        var state = SearchDebounceState()
        state.results = [
            SearchResult(id: "1", title: "Test", description: "", category: "Articles", relevanceScore: 0.9)
        ]
        state.hasSearched = true
        state.searchError = "Some error"
        
        searchDebounceReducer(state: &state, action: .clearResults)
        
        #expect(state.results.isEmpty)
        #expect(state.hasSearched == false)
        #expect(state.searchError == nil)
    }
    
    @Test("Cancel search")
    @MainActor
    func testCancelSearch() async {
        var state = SearchDebounceState()
        state.isSearching = true
        state.pendingSearchId = UUID()
        
        searchDebounceReducer(state: &state, action: .cancelSearch)
        
        #expect(state.isSearching == false)
        #expect(state.pendingSearchId == nil)
    }
    
    @Test("Search with category")
    func testSearchWithCategory() async throws {
        let searchCategory = LockIsolated<SearchCategory>(.all)
        
        try await withDependencies {
            $0.searchClient.search = { _, category in
                searchCategory.withValue { $0 = category }
                return []
            }
        } operation: { @MainActor in
            let store = createSearchDebounceStore()
            
            // Select category
            await store.dispatch(.selectCategory(.products))
            
            // Perform search
            await store.dispatch(.updateQuery("test"))
            // Wait for debounce
            try await Task.sleep(for: .milliseconds(600))
            await store.waitForEffects()
            
            #expect(searchCategory.value == .products)
        }
    }
    
    @Test("Search error handling")
    func testSearchErrorHandling() async throws {
        try await withDependencies {
            $0.searchClient.search = { _, _ in
                throw SearchError.networkError
            }
        } operation: { @MainActor in
            let store = createSearchDebounceStore()
            
            await store.dispatch(.updateQuery("test"))
            // Wait for debounce
            try await Task.sleep(for: .milliseconds(600))
            await store.waitForEffects()
            
            #expect(store.currentState.searchError == "Network error. Please try again.")
            #expect(store.currentState.results.isEmpty)
            #expect(store.currentState.isSearching == false)
            #expect(store.currentState.hasSearched == true)
        }
    }
    
    @Test("Effect cancellation on new query")
    @MainActor
    func testEffectCancellationOnNewQuery() async throws {
        // Test that updating query cancels previous search
        let store = createSearchDebounceStore()
        
        // Start first search
        await store.dispatch(.updateQuery("first"))
        let firstId = store.currentState.pendingSearchId
        #expect(firstId != nil)
        #expect(store.currentState.isSearching == true)
        
        // Immediately update query (should cancel first search)
        await store.dispatch(.updateQuery("second"))
        let secondId = store.currentState.pendingSearchId
        #expect(secondId != nil)
        #expect(firstId != secondId)
        #expect(store.currentState.isSearching == true)
        
        // The cancellation happens through the beforeDispatch handler
        // which cancels effects when updateQuery is called
    }
}