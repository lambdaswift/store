import Testing
@testable import StoreExamples
@testable import Store

@Suite("Counter Example Tests")
struct CounterExampleTests {
    
    @Test("Counter initial state")
    func testInitialState() async {
        let store = await createCounterStore()
        #expect(await store.currentState.count == 0)
        
        let storeWith10 = await createCounterStore(initialCount: 10)
        #expect(await storeWith10.currentState.count == 10)
    }
    
    @Test("Counter increment action")
    func testIncrement() async {
        let store = await createCounterStore()
        
        await store.dispatch(.increment)
        #expect(await store.currentState.count == 1)
        
        await store.dispatch(.increment)
        #expect(await store.currentState.count == 2)
        
        await store.dispatch(.increment)
        #expect(await store.currentState.count == 3)
    }
    
    @Test("Counter decrement action")
    func testDecrement() async {
        let store = await createCounterStore(initialCount: 5)
        
        await store.dispatch(.decrement)
        #expect(await store.currentState.count == 4)
        
        await store.dispatch(.decrement)
        #expect(await store.currentState.count == 3)
        
        // Test going negative
        let storeAtZero = await createCounterStore(initialCount: 0)
        await storeAtZero.dispatch(.decrement)
        #expect(await storeAtZero.currentState.count == -1)
    }
    
    @Test("Counter reset action")
    func testReset() async {
        let store = await createCounterStore(initialCount: 42)
        
        await store.dispatch(.reset)
        #expect(await store.currentState.count == 0)
        
        await store.dispatch(.increment)
        await store.dispatch(.increment)
        #expect(await store.currentState.count == 2)
        
        await store.dispatch(.reset)
        #expect(await store.currentState.count == 0)
    }
    
    @Test("Counter set action")
    func testSet() async {
        let store = await createCounterStore()
        
        await store.dispatch(.set(42))
        #expect(await store.currentState.count == 42)
        
        await store.dispatch(.set(-10))
        #expect(await store.currentState.count == -10)
        
        await store.dispatch(.set(0))
        #expect(await store.currentState.count == 0)
    }
    
    @Test("Counter mixed actions")
    func testMixedActions() async {
        let store = await createCounterStore()
        
        await store.dispatch(.increment)
        await store.dispatch(.increment)
        await store.dispatch(.decrement)
        #expect(await store.currentState.count == 1)
        
        await store.dispatch(.set(10))
        await store.dispatch(.increment)
        #expect(await store.currentState.count == 11)
        
        await store.dispatch(.reset)
        await store.dispatch(.decrement)
        #expect(await store.currentState.count == -1)
    }
    
    @Test("Counter state observation")
    func testStateObservation() async throws {
        let store = await createCounterStore()
        
        var observedStates: [CounterState] = []
        let task = Task {
            for await state in await store.states {
                observedStates.append(state)
                if observedStates.count >= 5 {
                    break
                }
            }
        }
        
        // Give time for subscription
        try await Task.sleep(nanoseconds: 10_000_000)
        
        await store.dispatch(.increment)
        await store.dispatch(.increment)
        await store.dispatch(.decrement)
        await store.dispatch(.reset)
        
        await task.value
        
        #expect(observedStates.count == 5)
        #expect(observedStates[0].count == 0) // Initial
        #expect(observedStates[1].count == 1) // After first increment
        #expect(observedStates[2].count == 2) // After second increment
        #expect(observedStates[3].count == 1) // After decrement
        #expect(observedStates[4].count == 0) // After reset
    }
    
    @Test("Counter reducer directly")
    func testReducerDirectly() {
        var state = CounterState(count: 5)
        
        counterReducer(state: &state, action: .increment)
        #expect(state.count == 6)
        
        counterReducer(state: &state, action: .decrement)
        counterReducer(state: &state, action: .decrement)
        #expect(state.count == 4)
        
        counterReducer(state: &state, action: .set(100))
        #expect(state.count == 100)
        
        counterReducer(state: &state, action: .reset)
        #expect(state.count == 0)
    }
}