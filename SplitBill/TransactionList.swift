//
//  TransactionList.swift
//  SplitBill
//
//  Created by fer0n on 07.09.23.
//

import Foundation
import SwiftUI

struct TransactionsList: View {
    @ObservedObject var cvm: ContentViewModel
    var card: Card
    var isSelected: Bool

    @State var attempts: Int = 0
    @State var transactionToEdit: Transaction?
    @State var newTransactionValue: String = ""

    func transactionTextField(_ transaction: Transaction) -> some View {
        CalcTextField(transaction.getStringValue(for: card),
                      text: (transaction == transactionToEdit)
                            ? $newTransactionValue
                            : .constant(transaction.getStringValue(for: card)),
                      onSubmit: { result in
            guard let res = result else {
                self.attempts += 1
                return
            }
            if res != 0 {
                cvm.editTransaction(transaction.id, value: res, card)
            }
            newTransactionValue = ""
            transactionToEdit = nil
        }, onEditingChanged: { edit in
            if edit {
                transactionToEdit = transaction
            } else {
                transactionToEdit = nil
                newTransactionValue = ""
            }
        },
            accentColor: card.color.uiColorFont,
            bgColor: UIColor(card.color.dark),
            textColor: UIColor(card.color.contrast)
        )
        .padding(.horizontal, 5)
        .gridColumnAlignment(transaction.label != nil ? .trailing : .leading)
        .lineLimit(1)
        .fixedSize()
        .onDisappear {
            transactionToEdit = nil
            newTransactionValue = ""
        }
        .disabled(transaction.locked)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .foregroundColor(Color.black.opacity(0.1))
        )
        .padding(.top, 3)
        .modifier(Shake(animatableData: CGFloat(self.attempts), isActive: transaction == transactionToEdit))
    }

    func labelRowItem(_ transaction: Transaction) -> some View {
        GridRow {
            Text(transaction.label ?? "")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .opacity(0.6)
                .gridColumnAlignment(.leading)
            transactionTextField(transaction)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation {
                        cvm.removeTransaction(transaction.id, of: card.id)
                    }
                }
            } label: {
                Text("deleteTransaction")
                Image(systemName: "minus.circle.fill")
            }
            if (transaction.shares.contains(where: { $0.value.manuallyAdjusted })) {
                Button {
                    withAnimation {
                        cvm.resetShare(transaction, of: card)
                    }
                } label: {
                    Text("resetManualShare")
                    Image(systemName: "eraser.fill")
                }
            }
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Grid(verticalSpacing: 0) {
                    ForEach(cvm.sortedTransactions(of: card), id: \.self) { tId in
                        if let transaction = cvm.getTransaction(tId) {
                            if transaction.type == .divider {
                                CardSpacer()
                                    .gridCellColumns(2)
                            } else {
                                labelRowItem(transaction)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .frame(minWidth: isSelected ? 100 : nil, alignment: .leading)
        }
        .frame(maxHeight: 250)
        .fixedSize()
    }
}
