# Store

A simple, robust Swift package for unidirectional data flow architecture using Swift concurrency.

## Overview

Store provides a lightweight state management solution that enforces unidirectional data flow, making your applications more testable, predictable, and maintainable. State mutations happen exclusively through reducers in response to actions, while side effects are handled via async functions with full cancellation support.

## Features

- ✅ Unidirectional data flow
- ✅ State mutations only through reducers
- ✅ Async effects with Swift concurrency
- ✅ Cancellable effects
- ✅ SwiftUI integration with `@Observable`
- ✅ Simple, focused API
- ✅ No dependency injection complexity
- ✅ Full testability

## Installation

### Swift Package Manager

Add Store to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Store.git", from: "0.0.1")
]
```

## Basic Usage

### Define Your State and Actions

```swift
import Store

struct AppState {
    var count: Int = 0
    var isLoading: Bool = false
    var user: User? = nil
}

enum AppAction {
    case increment
    case decrement
    case fetchUser(id: String)
    case userLoaded(User)
    case userLoadFailed(Error)
}
```

### Create a Reducer

```swift
let appReducer: Reducer<AppState, AppAction> = { state, action in
    switch action {
    case .increment:
        state.count += 1
        
    case .decrement:
        state.count -= 1
        
    case .fetchUser:
        state.isLoading = true
        
    case .userLoaded(let user):
        state.user = user
        state.isLoading = false
        
    case .userLoadFailed:
        state.isLoading = false
    }
}
```

### Define Effects

```swift
func userEffect(action: AppAction, state: AppState) async -> AppAction? {
    switch action {
    case .fetchUser(let id):
        do {
            let user = try await fetchUserFromAPI(id: id)
            return .userLoaded(user)
        } catch {
            return .userLoadFailed(error)
        }
    default:
        return nil
    }
}
```

### Create and Use the Store

```swift
let store = Store(
    initialState: AppState(),
    reducer: appReducer,
    effects: [userEffect]
)

// Dispatch actions
await store.dispatch(.increment)
await store.dispatch(.fetchUser(id: "123"))

// Observe state changes
for await state in store.states {
    print("Count: \(state.count)")
    print("User: \(state.user?.name ?? "None")")
}
```

## SwiftUI Integration

Store is `@Observable`, making it seamlessly integrate with SwiftUI views:

```swift
import SwiftUI

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    var body: some View {
        VStack {
            Text("Count: \(store.currentState.count)")
            
            HStack {
                Button("Decrement") {
                    Task {
                        await store.dispatch(.decrement)
                    }
                }
                
                Button("Increment") {
                    Task {
                        await store.dispatch(.increment)
                    }
                }
            }
            
            if store.currentState.isLoading {
                ProgressView()
            }
        }
    }
}

// In your App
@main
struct MyApp: App {
    @State private var store = Store(
        initialState: AppState(),
        reducer: appReducer,
        effects: [userEffect]
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
```

## Examples

### Counter Example

```swift
struct CounterState {
    var value: Int = 0
}

enum CounterAction {
    case increment
    case decrement
    case incrementAsync
}

let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
    switch action {
    case .increment, .incrementAsync:
        state.value += 1
    case .decrement:
        state.value -= 1
    }
}

func counterEffects(action: CounterAction, state: CounterState) async -> CounterAction? {
    switch action {
    case .incrementAsync:
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return .increment
    default:
        return nil
    }
}

// Usage
let store = Store(
    initialState: CounterState(),
    reducer: counterReducer,
    effects: [counterEffects]
)
```

### Todo List Example

```swift
struct TodoState {
    var todos: [Todo] = []
    var isLoading: Bool = false
}

enum TodoAction {
    case add(Todo)
    case remove(id: String)
    case toggleComplete(id: String)
    case loadTodos
    case todosLoaded([Todo])
}

let todoReducer: Reducer<TodoState, TodoAction> = { state, action in
    switch action {
    case .add(let todo):
        state.todos.append(todo)
        
    case .remove(let id):
        state.todos.removeAll { $0.id == id }
        
    case .toggleComplete(let id):
        if let index = state.todos.firstIndex(where: { $0.id == id }) {
            state.todos[index].isCompleted.toggle()
        }
        
    case .loadTodos:
        state.isLoading = true
        
    case .todosLoaded(let todos):
        state.todos = todos
        state.isLoading = false
    }
}
```

### Effect Cancellation Example

```swift
struct SearchState {
    var query: String = ""
    var results: [SearchResult] = []
    var isSearching: Bool = false
}

enum SearchAction {
    case updateQuery(String)
    case search
    case searchCompleted([SearchResult])
}

class SearchStore {
    private let store: Store<SearchState, SearchAction>
    private var searchTask: Task<Void, Never>?
    
    init() {
        store = Store(
            initialState: SearchState(),
            reducer: searchReducer,
            effects: []
        )
    }
    
    func search(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            await store.dispatch(.search)
            
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // Debounce
                let results = try await performSearch(query: query)
                await store.dispatch(.searchCompleted(results))
            } catch {
                // Handle cancellation
            }
        }
    }
}
```

## Testing

Store's design makes testing straightforward:

```swift
@Test
func testCounterIncrement() async {
    var state = CounterState(value: 0)
    counterReducer(&state, .increment)
    #expect(state.value == 1)
}

@Test
func testAsyncEffect() async {
    let store = Store(
        initialState: CounterState(),
        reducer: counterReducer,
        effects: [counterEffects]
    )
    
    await store.dispatch(.incrementAsync)
    
    // Wait for effect to complete
    try? await Task.sleep(nanoseconds: 1_500_000_000)
    
    let finalState = await store.currentState
    #expect(finalState.value == 2) // Initial increment + effect increment
}
```

## Requirements

- Swift 6.1+
- macOS 14.0+ / iOS 17.0+ / tvOS 17.0+ / watchOS 10.0+

## License

MIT