//
//  ShareTextField.swift
//  SplitBill
//

import SwiftUI

struct ShareTextField: View {
    let share: Share
    let card: Card
    let cornerRadius: CGFloat

    @Binding var floatingTransactionInfo: FloatingTransactionInfo
    @State var shareValue: String
    @State var attempts: Int = 0

    let editShare: (_ type: ShareEditType, _ cardId: UUID, _ value: Double?, _ onError: @escaping () -> Void) -> Void

    var body: some View {
        let padding = floatingTransactionInfo.padding

        HStack(alignment: .center, spacing: 0) {
            if share.manuallyAdjusted {
                Image(systemName: "arrow.uturn.backward")
                    .onTapGesture {
                        editShare(.reset, card.id, nil, {})
                    }
                    .padding(.leading, padding / 2)
                Divider()
                    .overlay(card.color.contrast)
                    .padding(padding / 2)
            } else {
                Spacer()
                    .frame(width: padding)
            }

            CalcTextField(
                "",
                text: $shareValue,
                onSubmit: { result in
                    guard let res = result else {
                        print("ERROR: couln't parse result")
                        self.attempts += 1
                        return
                    }
                    if res != share.value {
                        editShare(.edit, card.id, res, {
                            if let value = share.value {
                                shareValue = String(value)
                            }
                        })
                    }
                },
                onEditingChanged: { _ in
                },
                accentColor: card.color.uiColorFont,
                bgColor: UIColor(card.color.dark),
                textColor: UIColor(card.color.contrast),
                font: floatingTransactionInfo.uiFont
            )
            .padding(.trailing, padding)
            .fixedSize()
        }
        .fixedSize()
        .background(card.color.light)
        .foregroundColor(card.color.contrast)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .modifier(Shake(animatableData: CGFloat(self.attempts)))
    }
}
