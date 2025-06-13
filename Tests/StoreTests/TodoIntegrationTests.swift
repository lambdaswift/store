import Testing
@testable import Store

// Todo example from README
struct Todo: Equatable, Sendable {
    let id: String
    var title: String
    var isCompleted: Bool
}

struct TodoState: Equatable, Sendable {
    var todos: [Todo] = []
    var isLoading: Bool = false
}

enum TodoAction: Equatable, Sendable {
    case add(Todo)
    case remove(id: String)
    case toggleComplete(id: String)
    case loadTodos
    case todosLoaded([Todo])
}

@Test func testTodoListIntegration() async throws {
    let todoReducer: Reducer<TodoState, TodoAction> = { state, action in
        switch action {
        case .add(let todo):
            state.todos.append(todo)
            
        case .remove(let id):
            state.todos.removeAll { $0.id == id }
            
        case .toggleComplete(let id):
            if let index = state.todos.firstIndex(where: { $0.id == id }) {
                state.todos[index].isCompleted.toggle()
            }
            
        case .loadTodos:
            state.isLoading = true
            
        case .todosLoaded(let todos):
            state.todos = todos
            state.isLoading = false
        }
    }
    
    let store = await Store(
        initialState: TodoState(),
        reducer: todoReducer
    )
    
    // Test adding todos
    let todo1 = Todo(id: "1", title: "Buy groceries", isCompleted: false)
    let todo2 = Todo(id: "2", title: "Write tests", isCompleted: false)
    
    await store.dispatch(.add(todo1))
    #expect(await store.currentState.todos.count == 1)
    #expect(await store.currentState.todos[0] == todo1)
    
    await store.dispatch(.add(todo2))
    #expect(await store.currentState.todos.count == 2)
    
    // Test toggling completion
    await store.dispatch(.toggleComplete(id: "1"))
    #expect(await store.currentState.todos[0].isCompleted == true)
    
    await store.dispatch(.toggleComplete(id: "1"))
    #expect(await store.currentState.todos[0].isCompleted == false)
    
    // Test removing todo
    await store.dispatch(.remove(id: "1"))
    #expect(await store.currentState.todos.count == 1)
    #expect(await store.currentState.todos[0].id == "2")
}

@Test func testTodoLoadingWithEffects() async throws {
    let todoReducer: Reducer<TodoState, TodoAction> = { state, action in
        switch action {
        case .add(let todo):
            state.todos.append(todo)
            
        case .remove(let id):
            state.todos.removeAll { $0.id == id }
            
        case .toggleComplete(let id):
            if let index = state.todos.firstIndex(where: { $0.id == id }) {
                state.todos[index].isCompleted.toggle()
            }
            
        case .loadTodos:
            state.isLoading = true
            
        case .todosLoaded(let todos):
            state.todos = todos
            state.isLoading = false
        }
    }
    
    // Mock API effect
    func loadTodosEffect(action: TodoAction, state: TodoState) async -> TodoAction? {
        switch action {
        case .loadTodos:
            // Simulate API delay
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            let mockTodos = [
                Todo(id: "1", title: "Mock Todo 1", isCompleted: false),
                Todo(id: "2", title: "Mock Todo 2", isCompleted: true),
                Todo(id: "3", title: "Mock Todo 3", isCompleted: false)
            ]
            return .todosLoaded(mockTodos)
        default:
            return nil
        }
    }
    
    let store = await Store(
        initialState: TodoState(),
        reducer: todoReducer,
        effects: [loadTodosEffect]
    )
    
    // Test loading todos
    await store.dispatch(.loadTodos)
    
    // Effects run during dispatch, so by the time dispatch returns, todos are loaded
    #expect(await store.currentState.isLoading == false)
    #expect(await store.currentState.todos.count == 3)
    
    // Verify loaded todos
    let todos = await store.currentState.todos
    #expect(todos[0].title == "Mock Todo 1")
    #expect(todos[1].title == "Mock Todo 2")
    #expect(todos[2].title == "Mock Todo 3")
    #expect(todos[1].isCompleted == true)
}

@Test func testTodoStateObservation() async throws {
    let todoReducer: Reducer<TodoState, TodoAction> = { state, action in
        switch action {
        case .add(let todo):
            state.todos.append(todo)
        case .remove(let id):
            state.todos.removeAll { $0.id == id }
        case .toggleComplete(let id):
            if let index = state.todos.firstIndex(where: { $0.id == id }) {
                state.todos[index].isCompleted.toggle()
            }
        default:
            break
        }
    }
    
    let store = await Store(
        initialState: TodoState(),
        reducer: todoReducer
    )
    
    var observedStates: [TodoState] = []
    let observationTask = Task {
        for await state in await store.states {
            observedStates.append(state)
            if observedStates.count >= 4 {
                break
            }
        }
    }
    
    // Give observer time to start
    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    
    let todo1 = Todo(id: "1", title: "Task 1", isCompleted: false)
    let todo2 = Todo(id: "2", title: "Task 2", isCompleted: false)
    
    await store.dispatch(.add(todo1))
    await store.dispatch(.add(todo2))
    await store.dispatch(.toggleComplete(id: "1"))
    
    await observationTask.value
    
    #expect(observedStates.count == 4)
    #expect(observedStates[0].todos.count == 0) // Initial state
    #expect(observedStates[1].todos.count == 1) // After adding first todo
    #expect(observedStates[2].todos.count == 2) // After adding second todo
    #expect(observedStates[3].todos[0].isCompleted == true) // After toggling
}

@Test func testComplexTodoScenario() async throws {
    let todoReducer: Reducer<TodoState, TodoAction> = { state, action in
        switch action {
        case .add(let todo):
            state.todos.append(todo)
        case .remove(let id):
            state.todos.removeAll { $0.id == id }
        case .toggleComplete(let id):
            if let index = state.todos.firstIndex(where: { $0.id == id }) {
                state.todos[index].isCompleted.toggle()
            }
        case .loadTodos:
            state.isLoading = true
        case .todosLoaded(let todos):
            state.todos = todos
            state.isLoading = false
        }
    }
    
    // Effect that auto-removes completed todos after a delay
    func autoRemoveEffect(action: TodoAction, state: TodoState) async -> TodoAction? {
        switch action {
        case .toggleComplete(let id):
            // If the todo is now completed, remove it after a delay
            if let todo = state.todos.first(where: { $0.id == id }), todo.isCompleted {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                return .remove(id: id)
            }
            return nil
        default:
            return nil
        }
    }
    
    let store = await Store(
        initialState: TodoState(),
        reducer: todoReducer,
        effects: [autoRemoveEffect]
    )
    
    // Add todos
    let todo1 = Todo(id: "1", title: "Auto-remove test", isCompleted: false)
    let todo2 = Todo(id: "2", title: "Keep this one", isCompleted: false)
    
    await store.dispatch(.add(todo1))
    await store.dispatch(.add(todo2))
    #expect(await store.currentState.todos.count == 2)
    
    // Toggle completion of first todo (should trigger auto-remove)
    await store.dispatch(.toggleComplete(id: "1"))
    
    // Wait for auto-remove effect
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // First todo should be removed
    #expect(await store.currentState.todos.count == 1)
    #expect(await store.currentState.todos[0].id == "2")
}