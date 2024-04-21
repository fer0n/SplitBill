//
//  CardListItem.swift
//  SplitBill
//
//  Created by fer0n on 21.04.24.
//

import Foundation
import SwiftUI

struct CardListItem: View {
    var card: Binding<Card>
    @ObservedObject var cvm: ContentViewModel
    var disableEdit: Bool = false

    @State private var showColorPicker = false
    @State var selectedColor: ColorKeys?

    var body: some View {
        HStack {
            (
                card.wrappedValue.isChosen
                    ? Image(systemName: "checkmark.circle.fill")
                    : Image(systemName: "circle")
            )
            .imageScale(.large)
            .onTapGesture {
                cvm.toggleChosen(card.id)
            }

            TextField(card.name.wrappedValue, text: card.name)
                .disabled(disableEdit)
                .onChange(of: card.wrappedValue.name, perform: { _ in
                    cvm.saveCardDataDebounced()
                })
                .submitLabel(.done)

            Spacer()
            if !disableEdit {
                Circle()
                    .strokeBorder(card.wrappedValue.color.font, lineWidth: 1)
                    .background(Circle().foregroundColor(card.wrappedValue.color.dark))
                    .frame(width: 25, height: 25)
                    .onTapGesture {
                        selectedColor = card.wrappedValue.colorKey
                        showColorPicker = true
                    }
                    .popover(isPresented: $showColorPicker) {
                        CustomColorPicker(isPresented: $showColorPicker,
                                          card: card,
                                          selectedColor: $selectedColor,
                                          setNewColor: setNewColor)
                            .padding(10)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in
            return 0
        }
    }

    func setNewColor(card: Card, color: ColorKeys) {
        cvm.setCardColor(card, color: color)
    }
}
