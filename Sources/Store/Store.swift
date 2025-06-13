import Foundation

/// A reducer is a function that takes the current state and an action, and mutates the state based on the action.
/// The state is passed as `inout` to allow direct mutation.
public typealias Reducer<State, Action> = (inout State, Action) -> Void

/// An effect is an async function that takes an action and the current state,
/// and optionally returns a new action to be dispatched.
public typealias Effect<State, Action> = (Action, State) async -> Action?

/// A store holds the application state and provides methods to dispatch actions and observe state changes.
@MainActor
public final class Store<State, Action> where State: Sendable, Action: Sendable {
    /// The current state of the store.
    private(set) public var currentState: State {
        didSet {
            // Notify all subscribers of state changes
            for continuation in continuations.values {
                continuation.yield(currentState)
            }
        }
    }
    
    /// The reducer function that handles state mutations.
    private let reducer: Reducer<State, Action>
    
    /// The array of effects that handle side effects.
    private let effects: [Effect<State, Action>]
    
    /// Storage for state observation continuations
    private var continuations: [UUID: AsyncStream<State>.Continuation] = [:]
    
    /// Storage for active effect tasks
    private var effectTasks: Set<Task<Void, Never>> = []
    
    /// Creates a new store with the given initial state, reducer, and effects.
    /// - Parameters:
    ///   - initialState: The initial state of the store.
    ///   - reducer: The reducer function that handles state mutations.
    ///   - effects: An array of effect functions that handle side effects.
    public init(
        initialState: State,
        reducer: @escaping Reducer<State, Action>,
        effects: [Effect<State, Action>] = []
    ) {
        self.currentState = initialState
        self.reducer = reducer
        self.effects = effects
    }
    
    /// Dispatches an action to the store, which triggers the reducer and any associated effects.
    /// - Parameter action: The action to dispatch.
    public func dispatch(_ action: Action) async {
        // Apply the reducer to update the state
        reducer(&currentState, action)
        
        // Execute effects sequentially to avoid sendable issues
        for effect in effects {
            if let nextAction = await effect(action, currentState) {
                // Recursively dispatch any actions returned by effects
                await dispatch(nextAction)
            }
        }
    }
    
    /// Cancels all currently running effects.
    /// This is useful when you need to stop all side effects, for example when cleaning up.
    public func cancelEffects() {
        // Cancel all active effect tasks
        for task in effectTasks {
            task.cancel()
        }
        effectTasks.removeAll()
    }
    
    /// Executes a cancellable effect.
    /// The returned task can be cancelled to stop the effect execution.
    /// - Parameters:
    ///   - effect: The effect function to execute
    ///   - action: The action that triggered the effect
    /// - Returns: A task that can be cancelled
    @discardableResult
    public func executeEffect(_ effect: @escaping Effect<State, Action>, for action: Action) -> Task<Void, Never> {
        let task = Task { [weak self] in
            guard let self else { return }
            
            if let nextAction = await effect(action, self.currentState) {
                guard !Task.isCancelled else { return }
                await self.dispatch(nextAction)
            }
        }
        
        effectTasks.insert(task)
        
        // Clean up when task completes
        Task { [weak self] in
            _ = await task.value
            await self?.effectTasks.remove(task)
        }
        
        return task
    }
    
    /// An AsyncSequence that emits the current state whenever it changes.
    /// The sequence includes the current state immediately upon subscription.
    public var states: AsyncStream<State> {
        AsyncStream { continuation in
            let id = UUID()
            
            // Send the current state immediately
            continuation.yield(currentState)
            
            // Store the continuation for future updates
            continuations[id] = continuation
            
            // Set up termination handler to clean up
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }
}
