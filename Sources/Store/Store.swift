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
        
        // Execute effects
        for effect in effects {
            if let nextAction = await effect(action, currentState) {
                // Recursively dispatch any actions returned by effects
                await dispatch(nextAction)
            }
        }
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
