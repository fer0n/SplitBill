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
    @ObservedObject var vm: ContentViewModel
    @Binding var floatingTransactionInfo: FloatingTransactionInfo
    @Binding var floatingTransaction: Transaction?
    
    let handleTransactionChange: (_ updatedTransaction: Transaction) -> Void
    
    init(_ vm: ContentViewModel, _ floatingTransactionInfo: Binding<FloatingTransactionInfo>, _ floatingTransaction: Binding<Transaction?>, handleTransactionChange: @escaping (Transaction) -> Void) {
        self.vm = vm
        self._floatingTransactionInfo = floatingTransactionInfo
        self._floatingTransaction = floatingTransaction
        self.handleTransactionChange = handleTransactionChange
    }
    
    func editShare(type: ShareEditType, cardId: UUID, value: Double? = nil, onError: @escaping () -> Void) {
        guard var transaction = floatingTransaction else {
            print("no floatingTransaction found to edit share in")
            return
        }
        vm.handleError({
            switch(type) {
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
        let shares = floatingTransaction?.shares.map { $0.1 }.sorted { (s1, s2) -> Bool in
            guard let i1 = vm.getCardsIndex(of: s1.cardId), let i2 = vm.getCardsIndex(of: s2.cardId) else { return false }
            return i1 < i2
        } ?? []
        let colorScheme = vm.imageIsLight ? ColorScheme.light : .dark
        
        HStack(alignment: .center, spacing: 0) {
            ForEach(shares, id: \.self) { share in
                let card = vm.getCardCopy(of: share.cardId)
                if (card != nil) {
                    ShareTextField(share: share, card: card!, cornerRadius: cornerRadius, floatingTransactionInfo: $floatingTransactionInfo, shareValue: String(share.value ?? 0), editShare: self.editShare)
                }
                if share.cardId != shares.last?.cardId {
                    Image(systemName: "plus")
                        .padding(padding)
                        .environment(\.colorScheme, colorScheme)
                }
            }
            if (shares.count > 0) {
                Image(systemName: "equal")
                    .padding(.leading, padding)
                    .environment(\.colorScheme, colorScheme)
            }
        }
        .font(.system(size: ((floatingTransaction?.boundingBox?.height ?? 30) / 1.5), weight: .semibold, design: .rounded))
        .padding(padding)
        .animation(nil, value: UUID())
        .background(
            Color.black.opacity(0)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, colorScheme)
        )
        .foregroundColor(.foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius + padding, style: .continuous))
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
        
        HStack {
            if (share.manuallyAdjusted) {
                Image(systemName: "arrow.uturn.backward")
                    .onTapGesture {
                        editShare(.reset, card.id, nil, {})
                    }
                    .padding(.leading, padding / 2)
                Divider()
                    .overlay(card.color.contrast)
                    .padding(.vertical, padding / 2)
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
                    if (res != share.value) {
                        editShare(.edit, card.id, res, {
                            if let v = share.value {
                                shareValue = String(v)
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

//struct EditableShares_Previews: PreviewProvider {
//    static var previews: some View {
//        EditableShares(ContentViewModel(), .constant(
//            FloatingTransactionInfo(
//                center: false,
//                width: 300,
//                value: "hello",
//                color: .green,
//                contrastColor: .white,
//                darkColor: .black,
//                cardColors: [
//                    .red,
//                    .green
//                ],
//                shares: [
//                    Share(value: 12, cardId: UUID()),
//                    Share(value: 10, cardId: UUID()),
//                ]
//            )
//        ), .constant(
//            Transaction(
//                value: 10
//            )
//        ), handleTransactionChange: { _ in })
//    }
//}
