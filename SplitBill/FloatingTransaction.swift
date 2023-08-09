//
//  FloatingTransaction.swift
//  SplitBill
//
//  Created by fer0n on 08.08.23.
//

import SwiftUI

struct FloatingTransactionView: View {
    @ObservedObject var vm = ContentViewModel()
    
    @State var floatingTransactionInfo = FloatingTransactionInfo(
        center: false,
        width: nil,
        value: "",
        color: .blue,
        contrastColor: .white)
    @State var floatingTransaction: Transaction? = nil
    @FocusState private var floatingTransactionIsFocused: Bool
    @State var floatingTransactionDisappearTimer: Timer? = nil
    
    
    func flashTransaction(_ t: Transaction) {
        if (vm.getFirstChosencardOfTransaction(t) != nil) {
            return
        }
        withAnimation {
            setFloatingTransactionColor(t)
            floatingTransaction = t
            floatingTransactionInfo.value = t.stringValue
        }
        debouncedHideFloatingTransaction()
    }
    
    
    func debouncedHideFloatingTransaction() {
        floatingTransactionDisappearTimer?.invalidate()
        floatingTransactionDisappearTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            withAnimation {
                floatingTransaction = nil
            }
        }
        floatingTransactionInfo.center = false
    }
    
    
    func handleTransactionLongPress(_ transaction: Transaction?, _ point: CGPoint?) {
        setFloatingTransactionColor(transaction)
        floatingTransactionInfo.editable = true
        floatingTransactionIsFocused = true
        if let t = transaction {
            // edit existing transaction
            floatingTransactionInfo.value = String(t.value)
            floatingTransactionInfo.center = false
            floatingTransaction = transaction
        } else {
            // new transaction
            guard let point = point else { return }
            floatingTransactionInfo.value = ""
            let boundingBox = vm.getMedianBoundingBox()
            floatingTransaction = Transaction(
                value: 0,
                boundingBox: CGRect(x: point.x - boundingBox.width / 2,
                                    y: point.y - boundingBox.height / 2,
                                    width: boundingBox.width,
                                    height: boundingBox.height))
            floatingTransactionInfo.center = true
        }
    }
    
    
    func setFloatingTransactionColor(_ transaction: Transaction?) {
        let firstactiveCard = vm.getFirstActiveCard()
        if let t = transaction, let card = vm.getFirstChosencardOfTransaction(t) {
            let cards = vm.getChosencardsOfTransaction(t)
            if let firstactiveCard = firstactiveCard, cards.contains(firstactiveCard) {
                floatingTransactionInfo.color = firstactiveCard.color.light
                floatingTransactionInfo.contrastColor = firstactiveCard.color.contrast
            } else {
                floatingTransactionInfo.color = card.color.light
                floatingTransactionInfo.contrastColor = card.color.contrast
            }
        } else {
            floatingTransactionInfo.color = firstactiveCard?.color.light ?? Color(vm.markerColor ?? .blue)
            floatingTransactionInfo.contrastColor = firstactiveCard?.color.contrast ?? .white
        }
    }
    
    
    func handleFreeformTransaction() {
        withAnimation {
            if let value = Double.parse(from: floatingTransactionInfo.value), var transaction = floatingTransaction {
                transaction.value = value
                let hitCard = vm.getFirstChosencardOfTransaction(transaction)
                if (hitCard != nil || vm.hasTransaction(transaction)) {
                    vm.correctTransaction(transaction)
                } else  {
                    let box = transaction.boundingBox ?? vm.getProposedMarkerRect(basedOn: transaction.boundingBox)
                    let t = vm.createNewTransaction(value: value, boundingBox: box)
                    vm.linkTransactionToActiveCards(t)
                }
            }
            floatingTransaction = nil
        }
        floatingTransactionInfo.center = false
        floatingTransactionInfo.editable = false
    }
    
    
    func handleSizeChange(_ size: CGSize) {
        withAnimation {
            floatingTransactionInfo.width = size.width
            floatingTransactionInfo.padding = size.height * 0.2
        }
    }

    
    var FloatingTransactionTextField: some View {
        ZStack {
            if (floatingTransactionInfo.editable) {
                TextField("", text: $floatingTransactionInfo.value, onEditingChanged: { edit in
                        if (!edit) {
                            handleFreeformTransaction()
                        } else {
                            floatingTransactionDisappearTimer?.invalidate()
                        }
                    })
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .disableAutocorrection(true)
                    .onSubmit {
                        handleFreeformTransaction()
                    }
                    .onSizeChange(handleSizeChange)
                    .fixedSize()
                    .focused($floatingTransactionIsFocused)
            } else {
                Text(floatingTransactionInfo.value)
                    .onSizeChange(handleSizeChange)
                    .onTapGesture {
                        floatingTransactionInfo.editable = true
                        floatingTransactionIsFocused = true
                    }
            }
        }
        .floatingTransactionModifier(floatingTransaction, floatingTransactionInfo)
    }
    
    var body: some View {
        ZStack {
            if (floatingTransaction != nil) {
                FloatingTransactionTextField
                    .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
                    .zIndex(1)
            }
        }
        .onAppear {
            vm.onImageLongPress = self.handleTransactionLongPress
            vm.onFlashTransaction = self.flashTransaction
        }
    }
}

struct FloatingTransactionInfo {
    init(center: Bool, width: CGFloat?, value: String, color: Color, contrastColor: Color) {
        self.center = center
        self.width = width
        self.value = value
        self.color = color
        self.contrastColor = contrastColor
    }
    var center: Bool
    var width: CGFloat?
    var padding: CGFloat = 0
    var value: String
    var color: Color
    var contrastColor: Color
    var editable = false
}


extension View {
    func floatingTransactionModifier(_ floatingTransaction: Transaction?, _ floatingTransactionInfo: FloatingTransactionInfo) -> some View {
        self
            .font(.system(size: (floatingTransaction?.boundingBox?.height ?? 30)))
            .animation(nil, value: UUID())
            .accentColor(.white)
            .foregroundColor(floatingTransactionInfo.contrastColor)
            .padding(.horizontal, floatingTransactionInfo.padding)
            .background(floatingTransactionInfo.color)
            .clipShape(RoundedRectangle(cornerRadius: floatingTransaction?.boundingBox?.cornerRadius ?? floatingTransaction?.boundingBox?.minX ?? 0))
            .position(x: floatingTransactionInfo.center
                          ? floatingTransaction?.boundingBox?.midX ?? 0
                          : (floatingTransaction?.boundingBox?.minX ?? 0)
                                - (floatingTransactionInfo.width ?? floatingTransaction?.boundingBox?.width ?? 0) / 2
                                - floatingTransactionInfo.padding * 3,
                      y: floatingTransaction?.boundingBox?.midY ?? 0)
    }
    
    func onSizeChange(_ onSizeChange: @escaping (_ size: CGSize) -> Void) -> some View {
        self
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ViewSizeKey.self, value: geometry.size)
                        .onPreferenceChange(ViewSizeKey.self) { s in
                            onSizeChange(s)
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
