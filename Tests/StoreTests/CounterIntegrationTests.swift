import Testing
@testable import Store

// Counter example from README
struct CounterState: Equatable, Sendable {
    var value: Int = 0
}

enum CounterAction: Equatable, Sendable {
    case increment
    case decrement
    case incrementAsync
}

@Test func testCounterIntegration() async throws {
    let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
        switch action {
        case .increment:
            state.value += 1
        case .decrement:
            state.value -= 1
        case .incrementAsync:
            break // Don't increment here, let the effect handle it
        }
    }
    
    func counterEffects(action: CounterAction, state: CounterState) async -> CounterAction? {
        switch action {
        case .incrementAsync:
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            return .increment
        default:
            return nil
        }
    }
    
    let store = await Store(
        initialState: CounterState(),
        reducer: counterReducer,
        effects: [counterEffects]
    )
    
    // Test basic increment/decrement
    await store.dispatch(.increment)
    #expect(await store.currentState.value == 1)
    
    await store.dispatch(.increment)
    #expect(await store.currentState.value == 2)
    
    await store.dispatch(.decrement)
    #expect(await store.currentState.value == 1)
    
    // Test async increment - effects run during dispatch, so we'll see the result after
    await store.dispatch(.incrementAsync)
    // Effect runs during dispatch and completes
    #expect(await store.currentState.value == 2)
}

@Test func testCounterStateObservation() async throws {
    let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
        switch action {
        case .increment:
            state.value += 1
        case .decrement:
            state.value -= 1
        case .incrementAsync:
            break
        }
    }
    
    let store = await Store(
        initialState: CounterState(),
        reducer: counterReducer
    )
    
    var observedStates: [CounterState] = []
    let observationTask = Task {
        for await state in await store.states {
            observedStates.append(state)
            if observedStates.count >= 5 {
                break
            }
        }
    }
    
    // Give observer time to start
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    await store.dispatch(.increment)
    await store.dispatch(.increment)
    await store.dispatch(.decrement)
    await store.dispatch(.increment)
    
    await observationTask.value
    
    #expect(observedStates.count == 5)
    #expect(observedStates[0].value == 0) // Initial
    #expect(observedStates[1].value == 1) // After first increment
    #expect(observedStates[2].value == 2) // After second increment
    #expect(observedStates[3].value == 1) // After decrement
    #expect(observedStates[4].value == 2) // After final increment
}

@Test func testCounterWithMultipleEffects() async throws {
    let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
        switch action {
        case .increment:
            state.value += 1
        case .decrement:
            state.value -= 1
        case .incrementAsync:
            break
        }
    }
    
    // Effect that triggers decrement when value reaches 5
    func limitEffect(action: CounterAction, state: CounterState) async -> CounterAction? {
        switch action {
        case .increment where state.value >= 5:
            return .decrement
        default:
            return nil
        }
    }
    
    // Logging effect (simulated)
    var loggedActions: [CounterAction] = []
    func loggingEffect(action: CounterAction, state: CounterState) async -> CounterAction? {
        loggedActions.append(action)
        return nil
    }
    
    let store = await Store(
        initialState: CounterState(),
        reducer: counterReducer,
        effects: [loggingEffect, limitEffect]  // Log first, then apply limit
    )
    
    // Increment to 4
    for _ in 0..<4 {
        await store.dispatch(.increment)
    }
    #expect(await store.currentState.value == 4)
    
    // Now increment to 5, which should trigger the limit effect
    await store.dispatch(.increment)
    
    // Should have triggered limit effect and decremented back to 4
    #expect(await store.currentState.value == 4)
    
    // Verify logging
    // We should have logged: 4 increments + 1 increment (that triggers limit) + 1 decrement (from the effect)
    #expect(loggedActions.count == 6)
    #expect(loggedActions[0] == .increment)
    #expect(loggedActions[1] == .increment)
    #expect(loggedActions[2] == .increment)
    #expect(loggedActions[3] == .increment)
    #expect(loggedActions[4] == .increment) // This one triggers the limit effect
    #expect(loggedActions[5] == .decrement) // From the limit effect
}