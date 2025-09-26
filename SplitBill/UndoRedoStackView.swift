//
//  UndoRedoStackView.swift
//  SplitBill
//

import SwiftUI

struct UndoRedoStackView: View {
    @Environment(\.undoManager) var undoManager
    @EnvironmentObject var cvm: ContentViewModel
    var size: CGFloat

    var body: some View {
        let canUndo = undoManager?.canUndo ?? false
        let canRedo = undoManager?.canRedo ?? false
        let undoDisabled = canRedo && !canUndo

        return VStack(alignment: .trailing, spacing: 10) {
            Button {
                withAnimation {
                    undoManager?.undo()
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: size, height: size)
                    .foregroundColor(Color.foregroundColor.opacity(undoDisabled ? 0.3 : 1))
                    .animation(nil, value: UUID())
            }
            .myGlassEffect(interactive: true)
            .disabled(undoDisabled)
            .animation(nil, value: UUID())
            .opacity(canUndo || canRedo ? 1 : 0)

            if canRedo {
                Button {
                    withAnimation {
                        undoManager?.redo()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .frame(width: size, height: size)
                }
                .myGlassEffect(interactive: true)
                .animation(nil, value: UUID())
            }
        }
    }
}
