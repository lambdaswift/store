import Testing
@testable import Store
@testable import StoreExamples

@Suite("UndoRedo Example Tests")
struct UndoRedoExampleTests {
    
    @Test("Initial state")
    func testInitialState() {
        let state = UndoRedoState()
        #expect(state.currentText == "")
        #expect(state.undoStack.isEmpty)
        #expect(state.redoStack.isEmpty)
        #expect(!state.canUndo)
        #expect(!state.canRedo)
    }
    
    @Test("Update text adds to undo stack")
    @MainActor
    func testUpdateText() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.updateText("Hello"))
        #expect(store.currentState.currentText == "Hello")
        #expect(store.currentState.undoStack == [""])
        #expect(store.currentState.redoStack.isEmpty)
        
        await store.dispatch(.updateText("Hello World"))
        #expect(store.currentState.currentText == "Hello World")
        #expect(store.currentState.undoStack == ["", "Hello"])
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Same text doesn't add to undo stack")
    @MainActor
    func testSameTextNoUndo() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(currentText: "Hello"),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.updateText("Hello"))
        #expect(store.currentState.currentText == "Hello")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Undo restores previous text")
    @MainActor
    func testUndo() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(
                currentText: "Third",
                undoStack: ["First", "Second"]
            ),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.undo)
        #expect(store.currentState.currentText == "Second")
        #expect(store.currentState.undoStack == ["First"])
        #expect(store.currentState.redoStack == ["Third"])
        
        await store.dispatch(.undo)
        #expect(store.currentState.currentText == "First")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack == ["Third", "Second"])
    }
    
    @Test("Undo with empty stack does nothing")
    @MainActor
    func testUndoEmptyStack() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(currentText: "Hello"),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.undo)
        #expect(store.currentState.currentText == "Hello")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Redo restores next text")
    @MainActor
    func testRedo() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(
                currentText: "First",
                redoStack: ["Second", "Third"]
            ),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.redo)
        #expect(store.currentState.currentText == "Third")
        #expect(store.currentState.undoStack == ["First"])
        #expect(store.currentState.redoStack == ["Second"])
        
        await store.dispatch(.redo)
        #expect(store.currentState.currentText == "Second")
        #expect(store.currentState.undoStack == ["First", "Third"])
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Redo with empty stack does nothing")
    @MainActor
    func testRedoEmptyStack() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(currentText: "Hello"),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.redo)
        #expect(store.currentState.currentText == "Hello")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("New text clears redo stack")
    @MainActor
    func testNewTextClearsRedoStack() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(
                currentText: "Current",
                undoStack: ["Previous"],
                redoStack: ["Next", "Future"]
            ),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.updateText("New Text"))
        #expect(store.currentState.currentText == "New Text")
        #expect(store.currentState.undoStack == ["Previous", "Current"])
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Clear action resets everything")
    @MainActor
    func testClear() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(
                currentText: "Some text",
                undoStack: ["First", "Second"],
                redoStack: ["Next", "Future"]
            ),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.clear)
        #expect(store.currentState.currentText == "")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Can undo and can redo properties")
    func testCanUndoRedo() {
        let emptyState = UndoRedoState()
        #expect(!emptyState.canUndo)
        #expect(!emptyState.canRedo)
        
        let withUndoState = UndoRedoState(undoStack: ["Previous"])
        #expect(withUndoState.canUndo)
        #expect(!withUndoState.canRedo)
        
        let withRedoState = UndoRedoState(redoStack: ["Next"])
        #expect(!withRedoState.canUndo)
        #expect(withRedoState.canRedo)
        
        let withBothState = UndoRedoState(undoStack: ["Previous"], redoStack: ["Next"])
        #expect(withBothState.canUndo)
        #expect(withBothState.canRedo)
    }
    
    @Test("Complex undo/redo sequence")
    @MainActor
    func testComplexSequence() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(),
            reducer: undoRedoReducer
        )
        
        // Type some text
        await store.dispatch(.updateText("Hello"))
        await store.dispatch(.updateText("Hello World"))
        await store.dispatch(.updateText("Hello World!"))
        
        #expect(store.currentState.currentText == "Hello World!")
        #expect(store.currentState.undoStack == ["", "Hello", "Hello World"])
        #expect(store.currentState.redoStack.isEmpty)
        
        // Undo twice
        await store.dispatch(.undo)
        await store.dispatch(.undo)
        
        #expect(store.currentState.currentText == "Hello")
        #expect(store.currentState.undoStack == [""])
        #expect(store.currentState.redoStack == ["Hello World!", "Hello World"])
        
        // Type new text (should clear redo stack)
        await store.dispatch(.updateText("Hello Swift"))
        
        #expect(store.currentState.currentText == "Hello Swift")
        #expect(store.currentState.undoStack == ["", "Hello"])
        #expect(store.currentState.redoStack.isEmpty)
        
        // Undo all the way
        await store.dispatch(.undo)
        await store.dispatch(.undo)
        
        #expect(store.currentState.currentText == "")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack == ["Hello Swift", "Hello"])
    }
    
    @Test("State equality")
    func testStateEquality() {
        let state1 = UndoRedoState(
            currentText: "Hello",
            undoStack: ["", "Hi"],
            redoStack: ["World"]
        )
        
        let state2 = UndoRedoState(
            currentText: "Hello",
            undoStack: ["", "Hi"],
            redoStack: ["World"]
        )
        
        let state3 = UndoRedoState(
            currentText: "Hello",
            undoStack: ["", "Hi"],
            redoStack: ["Universe"]
        )
        
        #expect(state1 == state2)
        #expect(state1 != state3)
    }
    
    @Test("Multiple undos and redos")
    @MainActor
    func testMultipleUndoRedo() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(),
            reducer: undoRedoReducer
        )
        
        // Build up some history
        let texts = ["One", "Two", "Three", "Four", "Five"]
        for text in texts {
            await store.dispatch(.updateText(text))
        }
        
        #expect(store.currentState.currentText == "Five")
        #expect(store.currentState.undoStack.count == 5) // "", "One", "Two", "Three", "Four"
        
        // Undo all
        for _ in 0..<5 {
            await store.dispatch(.undo)
        }
        
        #expect(store.currentState.currentText == "")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack == ["Five", "Four", "Three", "Two", "One"])
        
        // Redo all
        for _ in 0..<5 {
            await store.dispatch(.redo)
        }
        
        #expect(store.currentState.currentText == "Five")
        #expect(store.currentState.undoStack == ["", "One", "Two", "Three", "Four"])
        #expect(store.currentState.redoStack.isEmpty)
    }
    
    @Test("Undo redo with whitespace changes")
    @MainActor
    func testWhitespaceChanges() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(),
            reducer: undoRedoReducer
        )
        
        await store.dispatch(.updateText("Hello"))
        await store.dispatch(.updateText("Hello "))
        await store.dispatch(.updateText("Hello  "))
        
        #expect(store.currentState.undoStack.count == 3)
        
        await store.dispatch(.undo)
        #expect(store.currentState.currentText == "Hello ")
        
        await store.dispatch(.undo)
        #expect(store.currentState.currentText == "Hello")
    }
    
    @Test("Clear from complex state")
    @MainActor
    func testClearFromComplexState() async {
        let store = Store<UndoRedoState, UndoRedoAction>(
            initialState: UndoRedoState(),
            reducer: undoRedoReducer
        )
        
        // Build complex state
        await store.dispatch(.updateText("First"))
        await store.dispatch(.updateText("Second"))
        await store.dispatch(.updateText("Third"))
        await store.dispatch(.undo)
        await store.dispatch(.undo)
        
        #expect(!store.currentState.undoStack.isEmpty)
        #expect(!store.currentState.redoStack.isEmpty)
        
        await store.dispatch(.clear)
        
        #expect(store.currentState.currentText == "")
        #expect(store.currentState.undoStack.isEmpty)
        #expect(store.currentState.redoStack.isEmpty)
        #expect(!store.currentState.canUndo)
        #expect(!store.currentState.canRedo)
    }
}