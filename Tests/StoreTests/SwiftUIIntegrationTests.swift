import Testing
import SwiftUI
@testable import Store

// Simple counter for SwiftUI testing
struct CounterViewState: Equatable, Sendable {
    var count: Int = 0
}

enum CounterViewAction: Equatable, Sendable {
    case increment
    case decrement
    case reset
}

@Test func testObservableStore() async throws {
    let reducer: Reducer<CounterViewState, CounterViewAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .reset:
            state.count = 0
        }
    }
    
    let store = await Store(
        initialState: CounterViewState(),
        reducer: reducer
    )
    
    // Test basic state management
    await store.dispatch(.increment)
    #expect(await store.currentState.count == 1)
    
    await store.dispatch(.increment)
    #expect(await store.currentState.count == 2)
    
    await store.dispatch(.decrement)
    #expect(await store.currentState.count == 1)
    
    await store.dispatch(.reset)
    #expect(await store.currentState.count == 0)
    
    // The @Observable macro ensures that SwiftUI views will automatically
    // re-render when currentState changes
}

// Test that Store works with SwiftUI View
struct TestCounterView: View {
    let store: Store<CounterViewState, CounterViewAction>
    
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
        }
    }
}

@Test func testStoreInSwiftUIContext() async throws {
    let reducer: Reducer<CounterViewState, CounterViewAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .reset:
            state.count = 0
        }
    }
    
    let store = await Store(
        initialState: CounterViewState(count: 10),
        reducer: reducer
    )
    
    // Create a view with the store
    _ = TestCounterView(store: store)
    
    // Verify the view can access the store's state
    #expect(await store.currentState.count == 10)
    
    // Simulate button taps by dispatching actions
    await store.dispatch(.increment)
    #expect(await store.currentState.count == 11)
    
    await store.dispatch(.decrement)
    await store.dispatch(.decrement)
    #expect(await store.currentState.count == 9)
}

// Test combining @Observable with AsyncSequence
@Test func testObservableWithAsyncSequence() async throws {
    let reducer: Reducer<CounterViewState, CounterViewAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .reset:
            state.count = 0
        }
    }
    
    let store = await Store(
        initialState: CounterViewState(),
        reducer: reducer
    )
    
    // Track changes via AsyncSequence
    var asyncSequenceValues: [Int] = []
    let task = Task {
        for await state in await store.states {
            asyncSequenceValues.append(state.count)
            if asyncSequenceValues.count >= 4 {
                break
            }
        }
    }
    
    // Give time to subscribe
    try await Task.sleep(nanoseconds: 10_000_000)
    
    // Both @Observable and AsyncSequence should work together
    await store.dispatch(.increment)
    await store.dispatch(.increment)
    await store.dispatch(.decrement)
    
    await task.value
    
    #expect(asyncSequenceValues == [0, 1, 2, 1])
}