import SwiftUI
import Store

// MARK: - State & Actions

public struct CounterState: Equatable, Sendable {
    public var count: Int
    
    public init(count: Int = 0) {
        self.count = count
    }
}

public enum CounterAction: Equatable, Sendable {
    case increment
    case decrement
    case reset
    case set(Int)
}

// MARK: - Reducer

public func counterReducer(state: inout CounterState, action: CounterAction) {
    switch action {
    case .increment:
        state.count += 1
    case .decrement:
        state.count -= 1
    case .reset:
        state.count = 0
    case .set(let value):
        state.count = value
    }
}

// MARK: - Store Creation

@MainActor
public func createCounterStore(initialCount: Int = 0) -> Store<CounterState, CounterAction> {
    Store(
        initialState: CounterState(count: initialCount),
        reducer: counterReducer
    )
}

// MARK: - SwiftUI View

public struct CounterView: View {
    let store: Store<CounterState, CounterAction>
    
    public init(store: Store<CounterState, CounterAction>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Simple Counter")
                .font(.title)
            
            Text("\(store.currentState.count)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .contentTransition(.numericText())
                .animation(.spring(), value: store.currentState.count)
            
            HStack(spacing: 20) {
                Button(action: {
                    Task { await store.dispatch(.decrement) }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    Task { await store.dispatch(.reset) }
                }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                }
                
                Button(action: {
                    Task { await store.dispatch(.increment) }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                }
            }
            
            Divider()
                .padding(.vertical)
            
            VStack(spacing: 10) {
                Text("Quick Actions")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    Button("+10") {
                        Task { 
                            for _ in 0..<10 {
                                await store.dispatch(.increment)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Set to 42") {
                        Task { await store.dispatch(.set(42)) }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Set to -10") {
                        Task { await store.dispatch(.set(-10)) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.systemBackground))
        #endif
    }
}

// MARK: - Preview

#Preview("Counter Example") {
    CounterView(store: createCounterStore())
}

#Preview("Counter Starting at 100") {
    CounterView(store: createCounterStore(initialCount: 100))
}