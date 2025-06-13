import SwiftUI
import Store
import Dependencies

// MARK: - State

struct PaginationState: Equatable, Sendable {
    var items: [PaginationItem] = []
    var currentPage = 0
    var pageSize = 20
    var totalItems = 0
    var isLoading = false
    var hasMorePages: Bool {
        items.count < totalItems
    }
    var loadedPages: Set<Int> = []
    var error: String?
}

struct PaginationItem: Equatable, Identifiable, Sendable {
    let id: Int
    let title: String
    let description: String
    let timestamp: Date
}

// MARK: - Actions

enum PaginationAction: Equatable, Sendable {
    case loadNextPage
    case loadPage(Int)
    case setItems([PaginationItem], page: Int, total: Int)
    case setLoading(Bool)
    case setError(String?)
    case refresh
    case clearCache
}

// MARK: - Dependencies

struct PaginationClient: DependencyKey, Sendable {
    static let liveValue = PaginationClient()
    
    var loadPage: @Sendable (Int, Int) async throws -> (items: [PaginationItem], total: Int) = { page, pageSize in
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(500))
        
        // Simulate total of 100 items
        let total = 100
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, total)
        
        // Generate mock items
        let items = (startIndex..<endIndex).map { index in
            PaginationItem(
                id: index,
                title: "Item \(index + 1)",
                description: "Description for item \(index + 1)",
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 3600))
            )
        }
        
        return (items, total)
    }
}

extension DependencyValues {
    var paginationClient: PaginationClient {
        get { self[PaginationClient.self] }
        set { self[PaginationClient.self] = newValue }
    }
}

// MARK: - Reducer

@MainActor
func paginationReducer(state: inout PaginationState, action: PaginationAction) {
    switch action {
    case .loadNextPage:
        // Prevent duplicate loads
        guard !state.isLoading && state.hasMorePages else { return }
        // The effect will handle dispatching loadPage
        
    case .loadPage(let page):
        // Prevent loading already loaded pages
        guard !state.loadedPages.contains(page) else { return }
        
        state.isLoading = true
        state.error = nil
        
    case .setItems(let newItems, let page, let total):
        state.totalItems = total
        state.loadedPages.insert(page)
        
        // Append new items (avoiding duplicates)
        let existingIds = Set(state.items.map { $0.id })
        let uniqueNewItems = newItems.filter { !existingIds.contains($0.id) }
        state.items.append(contentsOf: uniqueNewItems)
        
        // Sort by ID to maintain order
        state.items.sort { $0.id < $1.id }
        
        if page > state.currentPage {
            state.currentPage = page
        }
        
    case .setLoading(let loading):
        state.isLoading = loading
        
    case .setError(let error):
        state.error = error
        
    case .refresh:
        state.items = []
        state.currentPage = 0
        state.loadedPages = []
        state.error = nil
        state.totalItems = 0
        // The effect will handle loading page 0
        
    case .clearCache:
        state.items = []
        state.loadedPages = []
        state.currentPage = 0
    }
}

// MARK: - Store Creation

@MainActor
func createPaginationStore(
    client: PaginationClient = .liveValue
) -> Store<PaginationState, PaginationAction> {
    Store(
        initialState: PaginationState(),
        reducer: paginationReducer,
        effects: [{ action, state in
            switch action {
            case .loadNextPage:
                guard !state.isLoading && state.hasMorePages else { return nil }
                let nextPage = state.currentPage + 1
                return .loadPage(nextPage)
                
            case .loadPage(let page):
                guard !state.loadedPages.contains(page) else { return nil }
                
                do {
                    let result = try await client.loadPage(page, state.pageSize)
                    return .setItems(result.items, page: page, total: result.total)
                } catch {
                    return .setError(error.localizedDescription)
                }
                
            case .setItems, .setError:
                // After setting items or error, turn off loading
                return .setLoading(false)
                
            case .refresh:
                // Trigger loading first page after clearing
                return .loadPage(0)
                
            default:
                return nil
            }
        }]
    )
}

// MARK: - View

struct PaginationExampleView: View {
    @State private var store = createPaginationStore()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.currentState.items) { item in
                        ItemRow(item: item)
                            .onAppear {
                                // Load more when approaching the end
                                if item.id == store.currentState.items.last?.id {
                                    Task {
                                        await store.dispatch(.loadNextPage)
                                    }
                                }
                            }
                    }
                    
                    if store.currentState.isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = store.currentState.error {
                        VStack(spacing: 8) {
                            Text("Error loading items")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                Task {
                                    await store.dispatch(.loadNextPage)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    if !store.currentState.hasMorePages && !store.currentState.items.isEmpty {
                        Text("All items loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Pagination Example")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Refresh") {
                        Task {
                            await store.dispatch(.refresh)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !store.currentState.items.isEmpty {
                    HStack {
                        Text("\(store.currentState.items.count) of \(store.currentState.totalItems) items")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("Pages loaded: \(store.currentState.loadedPages.count)")
                            .font(.caption)
                    }
                    .padding()
                    .background(.regularMaterial)
                }
            }
        }
        .onAppear {
            if store.currentState.items.isEmpty {
                Task {
                    await store.dispatch(.loadPage(0))
                }
            }
        }
    }
}

struct ItemRow: View {
    let item: PaginationItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(item.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct PaginationExample_Previews: PreviewProvider {
    static var previews: some View {
        PaginationExampleView()
    }
}