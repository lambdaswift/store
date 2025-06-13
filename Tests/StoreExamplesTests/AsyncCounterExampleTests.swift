import Testing
import Foundation
import Dependencies
@testable import StoreExamples
@testable import Store

@Suite("Async Counter Example Tests")
struct AsyncCounterExampleTests {
    
    @Test("Async counter initial state")
    @MainActor
    func testInitialState() async {
        let store = createAsyncCounterStore()
        #expect(store.currentState.count == 0)
        #expect(store.currentState.isIncrementing == false)
        #expect(store.currentState.history == [0])
        
        let storeWith10 = createAsyncCounterStore(initialCount: 10)
        #expect(storeWith10.currentState.count == 10)
        #expect(storeWith10.currentState.history == [10])
    }
    
    @Test("Basic increment and decrement")
    @MainActor
    func testBasicActions() async {
        let store = createAsyncCounterStore()
        
        await store.dispatch(.increment)
        #expect(store.currentState.count == 1)
        #expect(store.currentState.history == [0, 1])
        
        await store.dispatch(.decrement)
        #expect(store.currentState.count == 0)
        #expect(store.currentState.history == [0, 1, 0])
    }
    
    @Test("Increment by amount")
    @MainActor
    func testIncrementBy() async {
        let store = createAsyncCounterStore()
        
        await store.dispatch(.incrementBy(5))
        #expect(store.currentState.count == 5)
        
        await store.dispatch(.incrementBy(-3))
        #expect(store.currentState.count == 2)
        
        await store.dispatch(.incrementBy(10))
        #expect(store.currentState.count == 12)
        #expect(store.currentState.history == [0, 5, 2, 12])
    }
    
    @Test("Delayed increment")
    func testDelayedIncrement() async throws {
        let sleepDurations = LockIsolated<[Duration]>([])
        
        await withDependencies {
            $0.clock.sleep = { duration in
                sleepDurations.withValue { $0.append(duration) }
                // Instant completion for tests
            }
        } operation: { @MainActor in
            let store = createAsyncCounterStore()
            
            await store.dispatch(.delayedIncrement(seconds: 2.0))
            await store.waitForEffects()
            
            // Should have incremented after delay
            #expect(store.currentState.count == 1)
            
            // Verify the correct delay was requested
            let durations = sleepDurations.value
            #expect(durations.count == 1)
            #expect(durations[0] == .seconds(2.0))
        }
    }
    
    @Test("Multiple delayed increments")
    func testMultipleDelayedIncrements() async throws {
        await withDependencies {
            $0.clock.sleep = { _ in
                // Instant completion for tests
            }
        } operation: { @MainActor in
            let store = createAsyncCounterStore()
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await store.dispatch(.delayedIncrement(seconds: 0.5))
                }
                group.addTask {
                    await store.dispatch(.delayedIncrement(seconds: 1.0))
                }
            }
            
            await store.waitForEffects()
            
            // Both should complete
            #expect(store.currentState.count == 2)
        }
    }
    
    @Test("Auto increment start and stop")
    func testAutoIncrement() async throws {
        let callCount = LockIsolated(0)
        
        await withDependencies {
            $0.clock.sleep = { _ in
                let count = callCount.withValue { 
                    $0 += 1
                    return $0
                }
                if count > 2 {
                    throw CancellationError()
                }
            }
        } operation: { @MainActor in
            let store = createAsyncCounterStore()
            
            // Start auto increment
            await store.dispatch(.startAutoIncrement)
            #expect(store.currentState.isIncrementing == true)
            
            // Dispatch a couple increment actions to simulate the loop
            await store.dispatch(.incrementBy(1))
            await store.dispatch(.incrementBy(1))
            
            // Stop auto increment
            await store.dispatch(.stopAutoIncrement)
            #expect(store.currentState.isIncrementing == false)
            
            let count = store.currentState.count
            #expect(count == 2) // Should have incremented twice
        }
    }
    
    @Test("Undo functionality")
    @MainActor
    func testUndo() async {
        let store = createAsyncCounterStore()
        
        // Build some history
        await store.dispatch(.increment)
        await store.dispatch(.increment)
        await store.dispatch(.incrementBy(5))
        #expect(store.currentState.count == 7)
        #expect(store.currentState.history == [0, 1, 2, 7])
        
        // Undo once
        await store.dispatch(.undoLast)
        #expect(store.currentState.count == 2)
        #expect(store.currentState.history == [0, 1, 2])
        
        // Undo again
        await store.dispatch(.undoLast)
        #expect(store.currentState.count == 1)
        #expect(store.currentState.history == [0, 1])
        
        // Can't undo past initial state
        await store.dispatch(.undoLast)
        #expect(store.currentState.count == 0)
        #expect(store.currentState.history == [0])
        
        // Trying to undo with single history item does nothing
        await store.dispatch(.undoLast)
        #expect(store.currentState.count == 0)
        #expect(store.currentState.history == [0])
    }
    
    @Test("Reset action")
    @MainActor
    func testReset() async {
        let store = createAsyncCounterStore(initialCount: 10)
        
        // Add some state
        await store.dispatch(.increment)
        await store.dispatch(.startAutoIncrement)
        #expect(store.currentState.isIncrementing == true)
        
        // Reset
        await store.dispatch(.reset)
        #expect(store.currentState.count == 0)
        #expect(store.currentState.isIncrementing == false)
        #expect(store.currentState.history == [0])
    }
    
    @Test("Effect cancellation on reset")
    func testEffectCancellationOnReset() async throws {
        await withDependencies {
            $0.clock.sleep = { _ in
                // Instant completion for tests
            }
        } operation: { @MainActor in
            let store = createAsyncCounterStore()
            
            // Start auto increment
            await store.dispatch(.startAutoIncrement)
            
            // Reset should stop auto increment
            await store.dispatch(.reset)
            #expect(store.currentState.isIncrementing == false)
            
            // Verify count is reset to 0
            let count = store.currentState.count
            #expect(count == 0)
            #expect(store.currentState.history == [0])
        }
    }
    
    @Test("Reducer directly")
    func testReducerDirectly() {
        var state = AsyncCounterState(count: 5)
        
        asyncCounterReducer(state: &state, action: .increment)
        #expect(state.count == 6)
        #expect(state.history == [5, 6])
        
        asyncCounterReducer(state: &state, action: .startAutoIncrement)
        #expect(state.isIncrementing == true)
        
        asyncCounterReducer(state: &state, action: .stopAutoIncrement)
        #expect(state.isIncrementing == false)
    }
}