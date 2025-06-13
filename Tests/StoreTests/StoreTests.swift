import Testing
@testable import Store

struct TestState: Equatable, Sendable {
    var count: Int = 0
    var message: String = ""
}

enum TestAction: Equatable, Sendable {
    case increment
    case decrement
    case setMessage(String)
}

@Test func testReducerTypeAlias() async throws {
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .setMessage(let message):
            state.message = message
        }
    }
    
    var state = TestState()
    reducer(&state, .increment)
    #expect(state.count == 1)
    
    reducer(&state, .decrement)
    #expect(state.count == 0)
    
    reducer(&state, .setMessage("Hello"))
    #expect(state.message == "Hello")
}

@Test func testEffectTypeAlias() async throws {
    let effect: Effect<TestState, TestAction> = { action, state in
        switch action {
        case .increment where state.count >= 5:
            return .setMessage("Count is high!")
        default:
            return nil
        }
    }
    
    let state1 = TestState(count: 3)
    let result1 = await effect(.increment, state1)
    #expect(result1 == nil)
    
    let state2 = TestState(count: 5)
    let result2 = await effect(.increment, state2)
    #expect(result2 == .setMessage("Count is high!"))
}

@Test func testStoreInitialization() async throws {
    let initialState = TestState(count: 10, message: "Initial")
    let reducer: Reducer<TestState, TestAction> = { _, _ in }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer
    )
    
    #expect(await store.currentState == initialState)
}

@Test func testStoreWithEffects() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .setMessage(let message):
            state.message = message
        }
    }
    
    let effect: Effect<TestState, TestAction> = { action, state in
        return nil
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer,
        effects: [effect]
    )
    
    #expect(await store.currentState == initialState)
}

@Test func testDispatchUpdatesState() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .setMessage(let message):
            state.message = message
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer
    )
    
    await store.dispatch(.increment)
    #expect(await store.currentState.count == 1)
    
    await store.dispatch(.increment)
    #expect(await store.currentState.count == 2)
    
    await store.dispatch(.decrement)
    #expect(await store.currentState.count == 1)
    
    await store.dispatch(.setMessage("Hello"))
    #expect(await store.currentState.message == "Hello")
}

@Test func testDispatchWithEffects() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .setMessage(let message):
            state.message = message
        }
    }
    
    var effectCalled = false
    let effect: Effect<TestState, TestAction> = { action, state in
        effectCalled = true
        switch action {
        case .increment where state.count >= 3:
            return .setMessage("Count is \(state.count)")
        default:
            return nil
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer,
        effects: [effect]
    )
    
    await store.dispatch(.increment)
    #expect(effectCalled)
    #expect(await store.currentState.count == 1)
    #expect(await store.currentState.message == "")
    
    effectCalled = false
    await store.dispatch(.increment)
    #expect(effectCalled)
    #expect(await store.currentState.count == 2)
    #expect(await store.currentState.message == "")
    
    effectCalled = false
    await store.dispatch(.increment)
    #expect(effectCalled)
    #expect(await store.currentState.count == 3)
    #expect(await store.currentState.message == "Count is 3")
}

@Test func testMultipleEffects() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .setMessage(let message):
            state.message = message
        }
    }
    
    var effect1Called = false
    var effect2Called = false
    
    let effect1: Effect<TestState, TestAction> = { action, state in
        effect1Called = true
        return nil
    }
    
    let effect2: Effect<TestState, TestAction> = { action, state in
        effect2Called = true
        switch action {
        case .increment where state.count == 2:
            return .setMessage("Two!")
        default:
            return nil
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer,
        effects: [effect1, effect2]
    )
    
    await store.dispatch(.increment)
    #expect(effect1Called)
    #expect(effect2Called)
    
    effect1Called = false
    effect2Called = false
    await store.dispatch(.increment)
    #expect(effect1Called)
    #expect(effect2Called)
    #expect(await store.currentState.message == "Two!")
}

@Test func testStateObservation() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        case .setMessage(let message):
            state.message = message
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer
    )
    
    var receivedStates: [TestState] = []
    let task = Task {
        for await state in await store.states {
            receivedStates.append(state)
            if receivedStates.count >= 4 {
                break
            }
        }
    }
    
    // Give the task time to start and receive initial state
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    await store.dispatch(.increment)
    await store.dispatch(.setMessage("Hello"))
    await store.dispatch(.increment)
    
    await task.value
    
    #expect(receivedStates.count == 4)
    #expect(receivedStates[0] == TestState(count: 0, message: ""))  // Initial state
    #expect(receivedStates[1] == TestState(count: 1, message: ""))  // After first increment
    #expect(receivedStates[2] == TestState(count: 1, message: "Hello"))  // After setMessage
    #expect(receivedStates[3] == TestState(count: 2, message: "Hello"))  // After second increment
}

@Test func testMultipleObservers() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        default:
            break
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer
    )
    
    var observer1States: [TestState] = []
    var observer2States: [TestState] = []
    
    let task1 = Task {
        for await state in await store.states {
            observer1States.append(state)
            if observer1States.count >= 3 {
                break
            }
        }
    }
    
    let task2 = Task {
        for await state in await store.states {
            observer2States.append(state)
            if observer2States.count >= 3 {
                break
            }
        }
    }
    
    // Give the tasks time to start and receive initial state
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    await store.dispatch(.increment)
    await store.dispatch(.increment)
    
    await task1.value
    await task2.value
    
    #expect(observer1States.count == 3)
    #expect(observer2States.count == 3)
    #expect(observer1States == observer2States)
}

@Test func testObserverTermination() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        default:
            break
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer
    )
    
    var receivedStates: [TestState] = []
    let task = Task {
        for await state in await store.states {
            receivedStates.append(state)
            if receivedStates.count >= 2 {
                break  // Terminate early
            }
        }
    }
    
    // Give the task time to start and receive initial state
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    await store.dispatch(.increment)
    await task.value  // Wait for task to complete
    
    // Dispatch more actions after observer terminated
    await store.dispatch(.increment)
    await store.dispatch(.increment)
    
    // Give time for any unexpected states to arrive
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    #expect(receivedStates.count == 2)  // Should only have initial + 1 update
}

@Test func testEffectCancellation() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .setMessage(let message):
            state.message = message
        default:
            break
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer,
        effects: []
    )
    
    var effectCompleted = false
    let slowEffect: Effect<TestState, TestAction> = { action, state in
        switch action {
        case .increment:
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                effectCompleted = true
                return .setMessage("Effect completed")
            } catch {
                // Cancelled
                return nil
            }
        default:
            return nil
        }
    }
    
    let task = await store.executeEffect(slowEffect, for: .increment)
    
    // Give the effect time to start
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    // Cancel the effect before it completes
    task.cancel()
    
    // Wait a bit longer than the effect would take
    try await Task.sleep(nanoseconds: 150_000_000) // 150ms
    
    #expect(effectCompleted == false)
    #expect(await store.currentState.message == "")
}

@Test func testCancelAllEffects() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .setMessage(let message):
            state.message = message
        default:
            break
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer,
        effects: []
    )
    
    var effect1Completed = false
    var effect2Completed = false
    
    let effect1: Effect<TestState, TestAction> = { action, state in
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            effect1Completed = true
            return .setMessage("Effect 1")
        } catch {
            return nil
        }
    }
    
    let effect2: Effect<TestState, TestAction> = { action, state in
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            effect2Completed = true
            return .setMessage("Effect 2")
        } catch {
            return nil
        }
    }
    
    // Start multiple effects
    await store.executeEffect(effect1, for: .increment)
    await store.executeEffect(effect2, for: .increment)
    
    // Give effects time to start
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    // Cancel all effects
    await store.cancelEffects()
    
    // Wait for effects to complete
    try await Task.sleep(nanoseconds: 150_000_000) // 150ms
    
    #expect(effect1Completed == false)
    #expect(effect2Completed == false)
    #expect(await store.currentState.message == "")
}

@Test func testEffectTaskCompletion() async throws {
    let initialState = TestState()
    let reducer: Reducer<TestState, TestAction> = { state, action in
        switch action {
        case .increment:
            state.count += 1
        case .setMessage(let message):
            state.message = message
        default:
            break
        }
    }
    
    let store = await Store(
        initialState: initialState,
        reducer: reducer,
        effects: []
    )
    
    let quickEffect: Effect<TestState, TestAction> = { action, state in
        // Quick effect that completes immediately
        return .setMessage("Quick!")
    }
    
    let task = await store.executeEffect(quickEffect, for: .increment)
    
    // Wait for effect to complete
    await task.value
    
    #expect(await store.currentState.message == "Quick!")
}
