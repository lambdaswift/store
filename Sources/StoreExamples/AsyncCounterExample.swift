import SwiftUI
import Store
import Dependencies

// MARK: - State & Actions

public struct AsyncCounterState: Equatable, Sendable {
    public var count: Int
    public var isIncrementing: Bool
    public var history: [Int]
    
    public init(count: Int = 0) {
        self.count = count
        self.isIncrementing = false
        self.history = [count]
    }
}

public enum AsyncCounterAction: Equatable, Sendable {
    case increment
    case decrement
    case delayedIncrement(seconds: Double)
    case incrementBy(Int)
    case startAutoIncrement
    case stopAutoIncrement
    case reset
    case undoLast
}

// MARK: - Reducer

public func asyncCounterReducer(state: inout AsyncCounterState, action: AsyncCounterAction) {
    switch action {
    case .increment:
        state.count += 1
        state.history.append(state.count)
        
    case .decrement:
        state.count -= 1
        state.history.append(state.count)
        
    case .delayedIncrement:
        // Effect will handle the delay
        break
        
    case .incrementBy(let amount):
        state.count += amount
        state.history.append(state.count)
        
    case .startAutoIncrement:
        state.isIncrementing = true
        
    case .stopAutoIncrement:
        state.isIncrementing = false
        
    case .reset:
        state.count = 0
        state.isIncrementing = false
        state.history = [0]
        
    case .undoLast:
        if state.history.count > 1 {
            state.history.removeLast()
            state.count = state.history.last ?? 0
        }
    }
}

// MARK: - Dependencies

public struct Clock: DependencyKey, Sendable {
    public static let liveValue = Clock()
    
    public var sleep: @Sendable (Duration) async throws -> Void = { duration in
        try await Task.sleep(for: duration)
    }
}

extension DependencyValues {
    public var clock: Clock {
        get { self[Clock.self] }
        set { self[Clock.self] = newValue }
    }
}

// MARK: - Effects

public func asyncCounterEffects(
    action: AsyncCounterAction,
    state: AsyncCounterState
) async -> AsyncCounterAction? {
    @Dependency(\.clock) var clock
    switch action {
    case .delayedIncrement(let seconds):
        do {
            try await clock.sleep(.seconds(seconds))
            return .increment
        } catch {
            return nil
        }
        
    case .startAutoIncrement:
        // Start incrementing every second
        do {
            try await clock.sleep(.seconds(1))
            if state.isIncrementing {
                return .incrementBy(1)
            }
        } catch {
            return nil
        }
        
    case .incrementBy where state.isIncrementing:
        // Continue auto-incrementing
        do {
            try await clock.sleep(.seconds(1))
            if state.isIncrementing {
                return .incrementBy(1)
            }
        } catch {
            return nil
        }
        
    default:
        break
    }
    
    return nil
}

// MARK: - Store Creation

@MainActor
public func createAsyncCounterStore(
    initialCount: Int = 0
) -> Store<AsyncCounterState, AsyncCounterAction> {
    Store(
        initialState: AsyncCounterState(count: initialCount),
        reducer: asyncCounterReducer,
        effects: [{ action, state in
            await asyncCounterEffects(action: action, state: state)
        }]
    )
}

// MARK: - SwiftUI View

public struct AsyncCounterView: View {
    let store: Store<AsyncCounterState, AsyncCounterAction>
    
    public init(store: Store<AsyncCounterState, AsyncCounterAction>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Async Counter")
                .font(.title)
            
            Text("\(store.currentState.count)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(store.currentState.isIncrementing ? .green : .blue)
                .contentTransition(.numericText())
                .animation(.spring(), value: store.currentState.count)
            
            if store.currentState.isIncrementing {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Auto-incrementing...")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    Task { await store.dispatch(.decrement) }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
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
            
            VStack(spacing: 15) {
                Text("Async Actions")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    Button("Increment in 2s") {
                        Task { await store.dispatch(.delayedIncrement(seconds: 2)) }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Increment in 5s") {
                        Task { await store.dispatch(.delayedIncrement(seconds: 5)) }
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack(spacing: 10) {
                    if !store.currentState.isIncrementing {
                        Button("Start Auto +1/sec") {
                            Task { await store.dispatch(.startAutoIncrement) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button("Stop Auto") {
                            Task { await store.dispatch(.stopAutoIncrement) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                }
                
                HStack(spacing: 10) {
                    Button("Undo") {
                        Task { await store.dispatch(.undoLast) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.currentState.history.count <= 1)
                    
                    Button("Reset") {
                        Task { await store.dispatch(.reset) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Divider()
                .padding(.vertical)
            
            VStack(alignment: .leading) {
                Text("History (last 5)")
                    .font(.headline)
                
                HStack {
                    ForEach(store.currentState.history.suffix(5), id: \.self) { value in
                        Text("\(value)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
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

#Preview("Async Counter") {
    AsyncCounterView(store: createAsyncCounterStore())
}

#Preview("Async Counter Starting at 10") {
    AsyncCounterView(store: createAsyncCounterStore(initialCount: 10))
}