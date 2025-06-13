import Foundation

/// A reducer is a function that takes the current state and an action, and mutates the state based on the action.
/// The state is passed as `inout` to allow direct mutation.
public typealias Reducer<State, Action> = (inout State, Action) -> Void

/// An effect is an async function that takes an action and the current state,
/// and optionally returns a new action to be dispatched.
public typealias Effect<State, Action> = (Action, State) async -> Action?
