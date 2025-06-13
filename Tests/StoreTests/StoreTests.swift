import Testing
@testable import Store

struct TestState: Equatable {
    var count: Int = 0
    var message: String = ""
}

enum TestAction: Equatable {
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
