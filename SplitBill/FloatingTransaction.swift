//
//  FloatingTransaction.swift
//  SplitBill
//
//  Created by fer0n on 08.08.23.
//

import SwiftUI

struct FloatingTransactionView: View {
    @ObservedObject var cvm = ContentViewModel()

    @State var floatingTransactionInfo = FloatingTransactionInfo(
        center: false,
        width: nil,
        value: "",
        color: .neutralGray)
    @State var floatingTransaction: Transaction?
    @FocusState private var floatingTransactionIsFocused: Bool
    @State var floatingTransactionDisappearTimer: Timer?
    @State var attempts: Int = 0

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
                    floatingTransaction = nil
                }
            }
        }
        floatingTransactionInfo.center = false
        floatingTransactionInfo.editable = false
    }

    func handleTransactionLongPress(_ transaction: Transaction?, _ point: CGPoint?) {
        withAnimation {
            setFloatingTransactionColor(transaction)
            floatingTransactionInfo.editable = true
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

    var floatingTransactionTextField: some View {
        ZStack {
            if floatingTransactionInfo.editable {
                CalcTextField(
                    "",
                    text: $floatingTransactionInfo.value,
                    onSubmit: { result in
                        guard let res = result else {
                            self.attempts += 1
                            return
                        }
                        if res != 0 {
                            floatingTransactionInfo.value = String(res)
                        }
                    },
                    onEditingChanged: { edit in
                        if !edit {
                            handleFreeformTransaction()
                        } else {
                            floatingTransactionDisappearTimer?.invalidate()
                        }
                    },
                    accentColor: floatingTransactionInfo.color.uiColorFont,
                    bgColor: UIColor(floatingTransactionInfo.color.dark),
                    textColor: UIColor(floatingTransactionInfo.color.contrast),
                    font: floatingTransactionInfo.uiFont
                )
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .disableAutocorrection(true)
                .fixedSize()
                .focused($floatingTransactionIsFocused)
            } else {
                Text(floatingTransactionInfo.value)
                    .onTapGesture {
                        floatingTransactionInfo.editable = true
                        floatingTransactionIsFocused = true
                    }
            }
        }
        .floatingTransactionModifier(floatingTransaction, floatingTransactionInfo)
        .modifier(Shake(animatableData: CGFloat(self.attempts)))
    }

    var body: some View {
        ZStack {
            if floatingTransaction != nil {
                HStack {
                    if floatingTransaction?.shares.count ?? 0 > 1 {
                        EditableShares(cvm,
                                       $floatingTransactionInfo,
                                       $floatingTransaction,
                                       handleTransactionChange: self.handleFreeformTransaction)
                    }
                    floatingTransactionTextField
                }
                .onSizeChange(handleSizeChange)
                .accentColor(.white)
                .foregroundColor(floatingTransactionInfo.color.contrast)
                .font(.system(size: (floatingTransaction?.boundingBox?.height ?? 30),
                              weight: .semibold, design: .rounded))
                .floatingTransactionPosition(floatingTransaction, floatingTransactionInfo)
            }
        }
        .onAppear {
            cvm.onImageLongPress = self.handleTransactionLongPress
            cvm.onFlashTransaction = self.flashTransaction
            cvm.onEmptyTap = self.handleEmptyTap
        }
        .onChange(of: cvm.image) { _ in
            floatingTransaction = nil
        }
    }
}

struct FloatingTransactionInfo {
    init(center: Bool, width: CGFloat?, value: String, color: ColorKeys, cardColors: [Color] = []) {
        self.center = center
        self.width = width
        self.value = value
        self.cardColors = cardColors
        self.colorKey = color
    }

    var center: Bool
    var width: CGFloat?
    var padding: CGFloat = 0
    var value: String
    var colorKey: ColorKeys
    var editable = false
    var cardColors: [Color]
    var uiFont: UIFont = UIFont.rounded(ofSize: 20, weight: .semibold)

    var color: CardColor {
        get {
            CardColor.get(colorKey)
        }
        set {
            self.colorKey = newValue.id
        }
    }
}

extension View {
    func floatingTransactionModifier(_ floatingTransaction: Transaction?,
                                     _ floatingTransactionInfo: FloatingTransactionInfo) -> some View {
        self
            .padding(.horizontal, floatingTransactionInfo.padding)
            .floatingTransactionBackground(floatingTransaction, floatingTransactionInfo)
    }

    func floatingTransactionPosition(_ floatingTransaction: Transaction?,
                                     _ floatingTransactionInfo: FloatingTransactionInfo) -> some View {
        self
            .position(x: floatingTransactionInfo.center
                      ? floatingTransaction?.boundingBox?.midX ?? 0
                      : (floatingTransaction?.boundingBox?.minX ?? 0)
                      - (floatingTransactionInfo.width ?? floatingTransaction?.boundingBox?.width ?? 0) / 2
                      - floatingTransactionInfo.padding * 2,
                      y: floatingTransaction?.boundingBox?.midY ?? 0)
    }

    func floatingTransactionBackground(_ floatingTransaction: Transaction?,
                                       _ floatingTransactionInfo: FloatingTransactionInfo) -> some View {
        self
            .background(
                GeometryReader { geometry in
                    ZStack {
                        ForEach(floatingTransactionInfo.cardColors, id: \.self) { color in
                            Rectangle()
                                .fill(color)
                                .frame(width: geometry.size.width / CGFloat(floatingTransactionInfo.cardColors.count),
                                       height: geometry.size.height)
                                .offset(x: CGFloat(floatingTransactionInfo.cardColors.firstIndex(of: color)!)
                                        * (geometry.size.width / CGFloat(floatingTransactionInfo.cardColors.count)),
                                        y: 0)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius:
                                            floatingTransaction?.boundingBox?.cornerRadius
                                            ?? floatingTransaction?.boundingBox?.minX
                                            ?? 0
                                       ))
    }

    func onSizeChange(_ onSizeChange: @escaping (_ size: CGSize) -> Void) -> some View {
        self
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ViewSizeKey.self, value: geometry.size)
                        .onPreferenceChange(ViewSizeKey.self) { size in
                            onSizeChange(size)
                        }
                }
            )
    }
}

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
