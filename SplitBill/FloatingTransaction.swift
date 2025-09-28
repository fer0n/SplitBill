//
//  FloatingTransaction.swift
//  SplitBill
//
//  Created by fer0n on 08.08.23.
//

import SwiftUI

struct FloatingTransactionView: View {
    @EnvironmentObject var cvm: ContentViewModel
    @Environment(\.colorScheme) var colorScheme

    @State var floatingTransactionInfo = FloatingTransactionInfo(
        center: false,
        width: nil,
        value: "",
        color: .neutralGray)
    @State var floatingTransaction: Transaction?
    @FocusState private var floatingTransactionIsFocused: Bool
    @FocusState private var editableSharesFocused: Bool

    @State var floatingTransactionDisappearTimer: Timer?
    @State var attempts: Int = 0

    var body: some View {
        ZStack {
            if floatingTransaction != nil {
                HStack(alignment: .center, spacing: 0) {
                    if floatingTransaction?.shares.count ?? 0 > 1 {
                        EditableShares($floatingTransactionInfo,
                                       $floatingTransaction,
                                       handleTransactionChange: self.handleFreeformTransaction)
                            .focused($editableSharesFocused)
                        Spacer()
                            .frame(width: padding)
                            .onChange(of: editableSharesFocused) {
                                if !editableSharesFocused {
                                    debouncedHideFloatingTransaction()
                                }
                            }
                    }
                    FloatingTransactionTextField(floatingTransactionInfo: $floatingTransactionInfo,
                                                 floatingTransaction: $floatingTransaction,
                                                 floatingTransactionIsFocused: $floatingTransactionIsFocused,
                                                 attempts: $attempts,
                                                 floatingTransactionDisappearTimer: floatingTransactionDisappearTimer,
                                                 handleFreeformTransaction: self.handleFreeformTransaction)
                }
                .geometryGroup()
                .padding(padding)
                .font(.system(size: (floatingTransaction?.boundingBox?.height ?? 30),
                              weight: .semibold, design: .rounded))
                .apply {
                    if #available(iOS 26.0, *) {
                        $0
                            .glassEffect(
                                .regular,
                                in: shape
                            )
                    } else {
                        $0
                            .background(
                                Color.black.opacity(0)
                                    .background(.ultraThinMaterial)
                            )
                            .clipShape(shape)
                    }
                }
                .foregroundStyle(cvm.getMarkerColor(colorScheme))
                .environment(\.colorScheme, cvm.getColorScheme(colorScheme))
                .onSizeChange(handleSizeChange)
                .floatingTransactionPosition(floatingTransaction, floatingTransactionInfo)
            }
        }
        .onAppear {
            cvm.onImageLongPress = self.handleTransactionLongPress
            cvm.onFlashTransaction = self.flashTransaction
            cvm.onEmptyTap = self.handleEmptyTap
        }
        .onChange(of: cvm.image) {
            floatingTransaction = nil
        }
    }

    var shape: some Shape {
        RoundedRectangle(cornerRadius: cornerRadius + padding, style: .continuous)
    }

    var cornerRadius: CGFloat {
        floatingTransaction?.boundingBox?.cornerRadius ?? 0
    }

    var padding: CGFloat {
        floatingTransactionInfo.padding / 2
    }

    func flashTransaction(_ tId: UUID, _ remove: Bool) {
        if remove && floatingTransaction == nil {
            return
        }

        let transaction = cvm.getTransaction(tId)
        guard let transaction = transaction,
              transaction.shares.count > 0 else {
            floatingTransaction = nil
            print("no transaction or card found to display")
            return
        }
        withAnimation {
            setFloatingTransactionColor(transaction)
            floatingTransaction = nil
            floatingTransaction = transaction
            floatingTransactionInfo.value = transaction.stringValue
            floatingTransactionInfo.uiFont = UIFont.rounded(ofSize: floatingTransaction?.boundingBox?.height ?? 30,
                                                            weight: .semibold)
        }
        debouncedHideFloatingTransaction()
    }

    func debouncedHideFloatingTransaction() {
        floatingTransactionDisappearTimer?.invalidate()
        withAnimation {
            if floatingTransactionInfo.value == "" {
                floatingTransaction = nil
            } else if let duration = cvm.previewDuration.timeInterval {
                floatingTransactionDisappearTimer = Timer.scheduledTimer(withTimeInterval: duration,
                                                                         repeats: false) { _ in
                    if !editableSharesFocused {
                        floatingTransaction = nil
                    }
                }
            }
        }
        floatingTransactionInfo.center = false
    }

    func handleTransactionLongPress(_ transaction: Transaction?, _ point: CGPoint?) {
        withAnimation {
            setFloatingTransactionColor(transaction)
            floatingTransactionIsFocused = true
            if let transaction = transaction {
                // edit existing transaction
                floatingTransactionInfo.value = String(transaction.value)
                floatingTransactionInfo.center = false
                floatingTransaction = transaction
                floatingTransactionInfo.uiFont = UIFont.rounded(ofSize: transaction.boundingBox?.height ?? 30,
                                                                weight: .semibold)
            } else {
                // new transaction
                guard let point = point else { return }
                floatingTransactionInfo.value = ""
                let boundingBox = cvm.getMedianBoundingBox()
                floatingTransaction = Transaction(
                    value: 0,
                    boundingBox: CGRect(x: point.x - boundingBox.width / 2,
                                        y: point.y - boundingBox.height / 2,
                                        width: boundingBox.width,
                                        height: boundingBox.height))
                floatingTransactionInfo.center = true
            }
        }
    }

    func handleEmptyTap() {
        if cvm.previewDuration == .tapAway {
            withAnimation {
                floatingTransaction = nil
            }
        }
    }

    func getCardColors(from cardIndeces: [Array<Card>.Index?]) -> [Color] {
        let cardIndeces = cardIndeces
            .sorted { (index1, index2) -> Bool in
                guard let index1, let index2 else { return false }
                return index1 < index2
            }
        let cardColors = cardIndeces.map {
            if let index = $0 {
                return cvm.cards[index].color.light
            }
            return Color.black
        }
        return cardColors
    }

    func setFloatingTransactionColor(_ transaction: Transaction?) {
        // get cardIds: either from transaction shares or from active cards
        var cardIds: [UUID] = []
        if let transaction = transaction {
            cardIds = Array(transaction.shares.keys)
        }
        if cardIds.isEmpty {
            cardIds = Array(cvm.activeCardsIds)
        }
        let cardIndices = cardIds.map { cvm.getCardsIndex(of: $0 )}

        // set CardColor, used for CalcTextField keyboard
        if let firstCardIndex = cardIndices[0] {
            let color = cvm.cards[firstCardIndex].color
            floatingTransactionInfo.color = color
        }

        // get colors of all cards
        let cardColors = getCardColors(from: cardIndices)
        floatingTransactionInfo.cardColors = !cardColors.isEmpty ? cardColors : [.black]
    }

    func handleFreeformTransaction(updatedTransaction: Transaction? = nil) {
        withAnimation {
            if let value = Double.parse(from: floatingTransactionInfo.value),
               var transaction = updatedTransaction ?? floatingTransaction {
                transaction.value = value
                let hitCard = cvm.getFirstChosencardOfTransaction(transaction)
                if hitCard != nil || cvm.hasTransaction(transaction) {
                    cvm.correctTransaction(transaction)
                } else {
                    let box = transaction.boundingBox ?? cvm.getProposedMarkerRect(basedOn: transaction.boundingBox)
                    let newTransaction = cvm.createNewTransaction(value: value, boundingBox: box)
                    cvm.linkTransactionToActiveCards(newTransaction)
                }
                try? transaction.refreshShares()
                self.floatingTransaction = nil // value doesn't update otherwise
                self.floatingTransaction = transaction
            }
            debouncedHideFloatingTransaction()
        }
    }

    func handleSizeChange(_ size: CGSize) {
        if floatingTransaction == nil { return }
        withAnimation {
            floatingTransactionInfo.width = size.width
            floatingTransactionInfo.padding = size.height * 0.2
        }
    }
}
