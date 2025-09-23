//
//  View.swift
//  SplitBill
//

import SwiftUI

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(
        _ condition: @autoclosure () -> Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }

    func myGlassEffect(interactive: Bool = false) -> some View {
        self.apply {
            if #available(iOS 26, *) {
                $0.glassEffect(.regular.interactive(interactive), in: .circle)
            } else {
                $0
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
        }
    }
}

extension View {
    func cardBackground(
        _ isSelected: Bool,
        _ selectedColor: Color,
        in shape: some Shape
    ) -> some View {
        self
            .apply {
                if #available(iOS 26, *) {
                    $0.glassEffect(
                        .regular.tint(
                            isSelected ? selectedColor : nil
                        ),
                        in: shape
                    )
                } else {
                    $0
                        .background(isSelected ? selectedColor : nil)
                        .background(.thinMaterial)
                        .background(isSelected ? Color.blue.opacity(0) : Color.black.opacity(0.3))
                        .clipShape(shape)
                }
            }
            .contentShape(shape)
    }
}
