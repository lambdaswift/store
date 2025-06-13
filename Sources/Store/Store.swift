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
    private(set) public var currentState: State
    
    /// The reducer function that handles state mutations.
    private let reducer: Reducer<State, Action>
    
    /// The array of effects that handle side effects.
    private let effects: [Effect<State, Action>]
    
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
}
