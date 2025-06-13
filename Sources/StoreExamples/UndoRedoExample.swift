import Foundation
import Store
import SwiftUI

// MARK: - State

public struct UndoRedoState: Equatable, Sendable {
    public var currentText: String
    public var undoStack: [String]
    public var redoStack: [String]
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init(
        currentText: String = "",
        undoStack: [String] = [],
        redoStack: [String] = []
    ) {
        self.currentText = currentText
        self.undoStack = undoStack
        self.redoStack = redoStack
    }
}

// MARK: - Actions

public enum UndoRedoAction: Equatable, Sendable {
    case updateText(String)
    case undo
    case redo
    case clear
}

// MARK: - Reducer

public func undoRedoReducer(state: inout UndoRedoState, action: UndoRedoAction) {
    switch action {
    case .updateText(let newText):
        if newText != state.currentText {
            state.undoStack.append(state.currentText)
            state.currentText = newText
            state.redoStack.removeAll()
        }

    case .undo:
        guard !state.undoStack.isEmpty else { return }
        let previousText = state.undoStack.removeLast()
        state.redoStack.append(state.currentText)
        state.currentText = previousText

    case .redo:
        guard !state.redoStack.isEmpty else { return }
        let nextText = state.redoStack.removeLast()
        state.undoStack.append(state.currentText)
        state.currentText = nextText

    case .clear:
        state.undoStack.removeAll()
        state.redoStack.removeAll()
        state.currentText = ""
    }
}

// MARK: - View

public struct UndoRedoView: View {
    @State private var store = Store<UndoRedoState, UndoRedoAction>(
        initialState: UndoRedoState(),
        reducer: undoRedoReducer
    )

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("Undo/Redo Text Editor")
                .font(.title)

            HStack {
                Button("Undo") {
                    Task { await store.dispatch(.undo) }
                }
                .disabled(!store.currentState.canUndo)

                Button("Redo") {
                    Task { await store.dispatch(.redo) }
                }
                .disabled(!store.currentState.canRedo)

                Spacer()

                Button("Clear All") {
                    Task { await store.dispatch(.clear) }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Editor:")
                    .font(.headline)

                #if os(macOS)
                    TextEditor(
                        text: Binding(
                            get: { store.currentState.currentText },
                            set: { newValue in
                                Task { await store.dispatch(.updateText(newValue)) }
                            }
                        )
                    )
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .border(Color.gray.opacity(0.3))
                #else
                    TextEditor(
                        text: Binding(
                            get: { store.currentState.currentText },
                            set: { newValue in
                                Task { await store.dispatch(.updateText(newValue)) }
                            }
                        )
                    )
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                #endif
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("History:")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Undo Stack (\(store.currentState.undoStack.count)):")
                            .font(.caption)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(
                                    Array(store.currentState.undoStack.enumerated().reversed()),
                                    id: \.offset
                                ) { index, text in
                                    Text(
                                        "\(index + 1). \(text.prefix(30))\(text.count > 30 ? "..." : "")"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxHeight: 100)

                            .frame(maxWidth: .infinity)

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Redo Stack (\(store.currentState.redoStack.count)):")
                                    .font(.caption)
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(
                                            Array(store.currentState.redoStack.enumerated()),
                                            id: \.offset
                                        ) { index, text in
                                            Text(
                                                "\(index + 1). \(text.prefix(30))\(text.count > 30 ? "..." : "")"
                                            )
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

#if DEBUG
    struct UndoRedoView_Previews: PreviewProvider {
        static var previews: some View {
            UndoRedoView()
        }
    }
#endif
