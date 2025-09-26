//
//  EditableShares.swift
//  SplitBill
//
//  Created by fer0n on 06.09.23.
//

import SwiftUI

enum ShareEditType {
    case reset
    case edit
}

struct EditableShares: View {
    @Namespace var namespace

    @EnvironmentObject var cvm: ContentViewModel
    @Binding var floatingTransactionInfo: FloatingTransactionInfo
    @Binding var floatingTransaction: Transaction?

    let handleTransactionChange: (_ updatedTransaction: Transaction) -> Void

    init(_ floatingTransactionInfo: Binding<FloatingTransactionInfo>,
         _ floatingTransaction: Binding<Transaction?>,
         handleTransactionChange: @escaping (Transaction) -> Void) {
        self._floatingTransactionInfo = floatingTransactionInfo
        self._floatingTransaction = floatingTransaction
        self.handleTransactionChange = handleTransactionChange
    }

    func editShare(type: ShareEditType, cardId: UUID, value: Double? = nil, onError: @escaping () -> Void) {
        guard var transaction = floatingTransaction else {
            print("no floatingTransaction found to edit share in")
            return
        }
        cvm.handleError({
            switch type {
            case .edit:
                try transaction.editShare(cardId: cardId, value: value)
            case .reset:
                try transaction.resetShare(cardId: cardId)
            }
        }, onError: {
            onError()
        }, onSuccess: {
            handleTransactionChange(transaction)
        })
    }

    func resetShare(cardId: UUID) {
        guard var transaction = floatingTransaction else {
            print("no floatingTransaction found to edit share in")
            return
        }
        try? transaction.resetShare(cardId: cardId)
        handleTransactionChange(transaction)
    }

    var body: some View {
        let cornerRadius = floatingTransaction?.boundingBox?.cornerRadius ?? 0
        let padding = floatingTransactionInfo.padding / 2
        let shares = floatingTransaction?.shares.map { $0.1 }.sorted { (share1, share2) -> Bool in
            guard let index1 = cvm.getCardsIndex(of: share1.cardId),
                  let index2 = cvm.getCardsIndex(of: share2.cardId) else {
                return false
            }
            return index1 < index2
        } ?? []
        let colorScheme = cvm.imageIsLight ? ColorScheme.light : .dark

        HStack(alignment: .center, spacing: 0) {
            ForEach(shares, id: \.self) { share in
                let card = cvm.getCardCopy(of: share.cardId)
                if card != nil {
                    ShareTextField(share: share, card: card!,
                                   cornerRadius: cornerRadius,
                                   floatingTransactionInfo: $floatingTransactionInfo,
                                   shareValue: String(share.value ?? 0),
                                   editShare: self.editShare)
                        .geometryGroup()
                        .matchedGeometryEffect(id: "share-\(share.cardId)", in: namespace)
                }
                if share.cardId != shares.last?.cardId {
                    Image(systemName: "plus")
                        .padding(padding)
                        .environment(\.colorScheme, colorScheme)
                        .geometryGroup()
                        .matchedGeometryEffect(id: "\(share.cardId)-plus", in: namespace)
                }
            }
            if shares.count > 0 {
                Image(systemName: "equal")
                    .padding(.leading, padding)
                    .environment(\.colorScheme, colorScheme)
                    .geometryGroup()
                    .matchedGeometryEffect(id: "share-equal", in: namespace)
            }
        }
        .geometryGroup()
        .font(.system(size: ((floatingTransaction?.boundingBox?.height ?? 30) / 1.5),
                      weight: .semibold, design: .rounded))
        .foregroundColor(.foregroundColor)
    }
}

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

#Preview {
    EditableShares(.constant(
        FloatingTransactionInfo(
            center: false,
            width: nil,
            value: "",
            color: .neutralGray,
            cardColors: [
                .red,
                .green,
            ],
            )
    ), .constant(
        Transaction(
            value: 10
        )
    ), handleTransactionChange: { _ in })
    .environmentObject(ContentViewModel())
}
