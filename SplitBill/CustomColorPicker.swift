//
//  CustomColorPicker.swift
//  SplitBill
//
//  Created by fer0n on 21.04.24.
//

import Foundation
import SwiftUI

struct CustomColorPicker: View {
    @Binding var isPresented: Bool
    @Binding var card: Card
    @Binding var selectedColor: ColorKeys?

    var setNewColor: (_ card: Card, _ color: ColorKeys) -> Void

    let colors = ColorKeys.allCases

    var body: some View {
        ZStack {
            Grid {
                GridRow {
                    ForEach(0..<4) { index in
                        singleColor(colors[index])
                    }
                }
                GridRow {
                    ForEach(4..<8) { index in
                        singleColor(colors[index])
                    }
                }
            }
        }
    }

    func singleColor(_ key: ColorKeys) -> some View {
        ZStack {
            Circle()
                .strokeBorder(CardColor.get(key).font, lineWidth: 1)
                .background(Circle().foregroundColor(CardColor.get(key).dark))
                .frame(width: 50, height: 50)
                .onTapGesture {
                    setNewColor(card, key)
                    isPresented = false
                }
            if selectedColor == key {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    @Previewable @State var show = true

    Button {
        show.toggle()
    } label: {
        Text(verbatim: "show")
    }
    .popover(isPresented: $show) {
        CustomColorPicker(
            isPresented: .constant(true),
            card: .constant(Card(name: "Test")),
            selectedColor: .constant(.cardRed),
            setNewColor: { _, _ in }
        )
        .padding(10)
        .presentationCompactAdaptation(.popover)
    }
}
