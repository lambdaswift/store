import Testing
@testable import Store
@testable import StoreExamples
import Foundation

@MainActor
struct PaginationExampleTests {
    
    func createTestStore() -> Store<PaginationState, PaginationAction> {
        let testClient = PaginationClient(
            loadPage: { page, pageSize in
                let total = 50
                let startIndex = page * pageSize
                let endIndex = min(startIndex + pageSize, total)
                
                let items = (startIndex..<endIndex).map { index in
                    PaginationItem(
                        id: index,
                        title: "Test Item \(index)",
                        description: "Test Description \(index)",
                        timestamp: Date(timeIntervalSince1970: 0).addingTimeInterval(TimeInterval(index))
                    )
                }
                
                return (items, total)
            }
        )
        
        return createPaginationStore(client: testClient)
    }
    
    @Test
    func initialState() {
        let state = PaginationState()
        
        #expect(state.items.isEmpty)
        #expect(state.currentPage == 0)
        #expect(state.pageSize == 20)
        #expect(state.totalItems == 0)
        #expect(state.isLoading == false)
        #expect(state.hasMorePages == false)
        #expect(state.loadedPages.isEmpty)
        #expect(state.error == nil)
    }
    
    @Test
    func hasMorePagesCalculation() {
        var state = PaginationState()
        
        // No items, no total
        #expect(state.hasMorePages == false)
        
        // Has items but less than total
        state.items = [
            PaginationItem(id: 0, title: "Item 1", description: "Desc 1", timestamp: Date())
        ]
        state.totalItems = 10
        #expect(state.hasMorePages == true)
        
        // Items equal to total
        state.items = Array(0..<10).map { id in
            PaginationItem(id: id, title: "Item \(id)", description: "Desc \(id)", timestamp: Date())
        }
        state.totalItems = 10
        #expect(state.hasMorePages == false)
    }
    
    @Test
    func loadFirstPage() async {
        let store = createTestStore()
        
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        
        #expect(store.currentState.items.count == 20)
        #expect(store.currentState.currentPage == 0)
        #expect(store.currentState.totalItems == 50)
        #expect(store.currentState.loadedPages.contains(0))
        #expect(store.currentState.isLoading == false)
        #expect(store.currentState.hasMorePages == true)
        
        // Verify items are in order
        for (index, item) in store.currentState.items.enumerated() {
            #expect(item.id == index)
            #expect(item.title == "Test Item \(index)")
        }
    }
    
    @Test
    func loadNextPage() async {
        let store = createTestStore()
        
        // Load first page
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        
        #expect(store.currentState.items.count == 20)
        #expect(store.currentState.isLoading == false)
        
        // Load next page
        await store.dispatch(.loadNextPage)
        await store.waitForEffects()
        // Wait for the nested loadPage effect
        await store.waitForEffects()
        
        #expect(store.currentState.items.count == 40) // 20 + 20
        #expect(store.currentState.currentPage == 1)
        #expect(store.currentState.loadedPages.contains(0))
        #expect(store.currentState.loadedPages.contains(1))
        #expect(store.currentState.hasMorePages == true)
        
        // Verify no duplicates and correct order
        let ids = store.currentState.items.map { $0.id }
        #expect(Set(ids).count == ids.count) // No duplicates
        #expect(ids == ids.sorted()) // In order
    }
    
    @Test
    func preventDuplicatePageLoads() async {
        let store = createTestStore()
        
        // Load page 0
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        
        let itemCountAfterFirstLoad = store.currentState.items.count
        
        // Try to load page 0 again
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        
        // Should not have loaded duplicate items
        #expect(store.currentState.items.count == itemCountAfterFirstLoad)
        #expect(store.currentState.loadedPages.count == 1)
    }
    
    @Test
    func preventLoadingWhileLoading() async {
        let store = createTestStore()
        
        // Manually set loading state
        await store.dispatch(.setLoading(true))
        
        // Set total items to simulate more pages
        await store.dispatch(.setItems([], page: 0, total: 100))
        
        // Try to load next page while loading
        await store.dispatch(.loadNextPage)
        
        // Should not start loading
        #expect(store.currentState.currentPage == 0)
        #expect(store.currentState.items.isEmpty)
    }
    
    @Test
    func loadAllPages() async {
        let store = createTestStore()
        
        // Load all pages (50 items, 20 per page = 3 pages)
        for page in 0..<3 {
            await store.dispatch(.loadPage(page))
            await store.waitForEffects()
        }
        
        #expect(store.currentState.items.count == 50)
        #expect(store.currentState.currentPage == 2)
        #expect(store.currentState.hasMorePages == false)
        #expect(store.currentState.loadedPages.count == 3)
        
        // Try to load next page when no more pages
        await store.dispatch(.loadNextPage)
        await store.waitForEffects()
        
        // Should not have changed
        #expect(store.currentState.items.count == 50)
    }
    
    @Test
    func refreshClearsAndReloads() async {
        let store = createTestStore()
        
        // Load some pages
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        await store.dispatch(.loadPage(1))
        await store.waitForEffects()
        
        #expect(store.currentState.items.count == 40)
        #expect(store.currentState.loadedPages.count == 2)
        
        // Refresh
        await store.dispatch(.refresh)
        await store.waitForEffects()
        // Wait for the nested loadPage effect
        await store.waitForEffects()
        
        // Should have cleared and reloaded first page
        #expect(store.currentState.items.count == 20)
        #expect(store.currentState.currentPage == 0)
        #expect(store.currentState.loadedPages.count == 1)
        #expect(store.currentState.loadedPages.contains(0))
        #expect(store.currentState.error == nil)
    }
    
    @Test
    func clearCache() async {
        let store = createTestStore()
        
        // Load some pages
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        await store.dispatch(.loadPage(1))
        await store.waitForEffects()
        
        // Clear cache
        await store.dispatch(.clearCache)
        
        #expect(store.currentState.items.isEmpty)
        #expect(store.currentState.loadedPages.isEmpty)
        #expect(store.currentState.currentPage == 0)
        #expect(store.currentState.totalItems == 50) // Total remains
    }
    
    @Test
    func setItemsMaintainsOrder() async {
        let store = createTestStore()
        
        // Add items out of order
        let items1 = [
            PaginationItem(id: 20, title: "Item 20", description: "Desc", timestamp: Date()),
            PaginationItem(id: 21, title: "Item 21", description: "Desc", timestamp: Date())
        ]
        
        let items2 = [
            PaginationItem(id: 0, title: "Item 0", description: "Desc", timestamp: Date()),
            PaginationItem(id: 1, title: "Item 1", description: "Desc", timestamp: Date())
        ]
        
        await store.dispatch(.setItems(items1, page: 1, total: 100))
        await store.dispatch(.setItems(items2, page: 0, total: 100))
        
        // Should be sorted by ID
        #expect(store.currentState.items.map { $0.id } == [0, 1, 20, 21])
    }
    
    @Test
    func errorHandling() async {
        let errorClient = PaginationClient(
            loadPage: { _, _ in
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
            }
        )
        let store = createPaginationStore(client: errorClient)
        
        await store.dispatch(.loadPage(0))
        await store.waitForEffects()
        
        #expect(store.currentState.error == "Test error")
        #expect(store.currentState.isLoading == false)
        #expect(store.currentState.items.isEmpty)
    }
    
    @Test
    func setLoadingState() async {
        let store = createTestStore()
        
        await store.dispatch(.setLoading(true))
        #expect(store.currentState.isLoading == true)
        
        await store.dispatch(.setLoading(false))
        #expect(store.currentState.isLoading == false)
    }
    
    @Test
    func setErrorState() async {
        let store = createTestStore()
        
        await store.dispatch(.setError("Network error"))
        #expect(store.currentState.error == "Network error")
        
        await store.dispatch(.setError(nil))
        #expect(store.currentState.error == nil)
    }
    
    @Test
    func avoidDuplicateItems() async {
        let store = createTestStore()
        
        // Add some items
        let items1 = [
            PaginationItem(id: 0, title: "Item 0", description: "Desc", timestamp: Date()),
            PaginationItem(id: 1, title: "Item 1", description: "Desc", timestamp: Date())
        ]
        
        await store.dispatch(.setItems(items1, page: 0, total: 10))
        
        // Try to add overlapping items
        let items2 = [
            PaginationItem(id: 1, title: "Item 1 Duplicate", description: "Desc", timestamp: Date()),
            PaginationItem(id: 2, title: "Item 2", description: "Desc", timestamp: Date())
        ]
        
        await store.dispatch(.setItems(items2, page: 1, total: 10))
        
        // Should only have 3 unique items
        #expect(store.currentState.items.count == 3)
        #expect(Set(store.currentState.items.map { $0.id }).count == 3)
        
        // Original item 1 should be preserved
        #expect(store.currentState.items[1].title == "Item 1")
    }
    
    @Test
    func paginationItemEquality() {
        let date = Date()
        let item1 = PaginationItem(id: 1, title: "Item", description: "Desc", timestamp: date)
        let item2 = PaginationItem(id: 1, title: "Item", description: "Desc", timestamp: date)
        let item3 = PaginationItem(id: 2, title: "Item", description: "Desc", timestamp: date)
        
        #expect(item1 == item2)
        #expect(item1 != item3)
    }
}