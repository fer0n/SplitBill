//
//  SingleCardView.swift
//  SplitBill
//
//  Created by fer0n on 19.08.23.
//

import SwiftUI


struct SingleCardView: View {
    @ObservedObject var vm: ContentViewModel
    @State var transactionToEdit: Transaction? = nil
    @State var newTransactionValue: String = ""
    @Binding public var showTransactions: Bool
    @Binding public var showEditCardSheet: Bool
    var card: Card
    var toggleTransaction: () -> Void
    let isSelected: Bool
    let handleAutoScroll: () -> Void
    
    
    init(vm: ContentViewModel, showTransactions: Binding<Bool>, showEditCardSheet: Binding<Bool>, card: Card, toggleTransaction: @escaping () -> Void, handleAutoScroll: @escaping () -> Void) {
        self.vm = vm
        self._showTransactions = showTransactions
        self.card = card
        self.toggleTransaction = toggleTransaction
        self.isSelected = card.isActive || vm.isActiveCard(card)
        self.handleAutoScroll = handleAutoScroll
        self._showEditCardSheet = showEditCardSheet
    }
    
    
    func hideTransactions() {
        if (showTransactions) {
            toggleTransaction()
        }
    }
    
    func calculateExpression(_ expression: String) -> Double?  {
        var result: Double? = nil
        do {
            try ObjC.catchException {
                var cleaned = expression.replacingOccurrences(of: ",", with: ".")
                var exp = NSExpression(format: cleaned)
                exp = exp.toFloatingPointDivision()
                result = exp.expressionValue(with: nil, context: nil) as? Double
            }
        } catch {
            print("Calc expression \(expression) can't be resolved: \(error)")
            result = nil
        }
        return result
    }
    
    func LabelRowItem(_ t: Transaction) -> some View {
        GridRow {
            Text(t.label ?? "")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .opacity(0.6)
                .gridColumnAlignment(.leading)
            TextField(String(t.getStringValue(for: card)), text: (t == transactionToEdit) ? $newTransactionValue : .constant(t.getStringValue(for: card)), onEditingChanged: { edit in
                if (edit) {
                    transactionToEdit = t
                } else {
                    transactionToEdit = nil
                    newTransactionValue = ""
                }
            })
            .keyboardType(.numbersAndPunctuation)
            .submitLabel(.done)
            .disableAutocorrection(true)
            .fixedSize()
            .disabled(t.locked)
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .gridColumnAlignment(t.label != nil ? .trailing : .leading)
            .onSubmit {
                if (newTransactionValue != "") {
                    let res = calculateExpression(newTransactionValue)
                    if let value = res {
                        vm.editTransaction(t.id, value: value, card)
                    }
                }
                newTransactionValue = ""
                transactionToEdit = nil
            }
            .onDisappear {
                transactionToEdit = nil
                newTransactionValue = ""
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation {
                        vm.removeTransaction(t.id, of: card.id)
                    }
                }
            } label: {
                Text("deleteTransaction")
                Image(systemName: "minus.circle.fill")
            }
            if (t.shares.contains(where: { $0.value.manuallyAdjusted })) {
                Button {
                    withAnimation {
                        vm.resetShare(t, of: card)
                    }
                } label: {
                    Text("resetManualShare")
                    Image(systemName: "eraser.fill")
                }
            }
        }
    }
    
    var TransactionsList: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Grid(verticalSpacing: 0) {
                    ForEach(vm.sortedTransactions(of: card), id: \.self) { tId in
                        if let transaction = vm.getTransaction(tId) {
                            if (transaction.type == .divider) {
                                CardSpacer()
                                    .gridCellColumns(2)
                            } else {
                                LabelRowItem(transaction)
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
    
    var TransactionsCard: some View {
        VStack(alignment: .center, spacing: 0) {
            if (!(showTransactions && isSelected)) {
                Spacer()
                    .frame(height: 20)
            } else if (card.transactionIds.count > 0) {
                TransactionsList
            } else {
                Text("empty")
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .italic()
                    .opacity(0.9)
            }
        }
        .foregroundColor(.white)
        .frame(minWidth: 80)
        .background(card.color.dark)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .padding(.bottom, 4)
        .scaleEffect(showTransactions && isSelected ? 1 : 0.5, anchor: .bottom)
        .opacity(showTransactions && isSelected ? 1 : 0)
        .clipped()
    }
    
    var SingleCard: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: isSelected && showTransactions ? .leading : .center, spacing: 0) {
                Text("\(vm.sumString(of: card))")
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Text("\(card.stringName)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            }
            if (isSelected && showTransactions) {
                Spacer()
            }
            Image(systemName: "chevron.down.circle.fill")
                .scaleEffect(isSelected && showTransactions ? 1 : 0.5)
                .opacity(isSelected && showTransactions ? 1 : 0)
                .font(.system(size: 20))
                .frame(width: isSelected && showTransactions ? nil : 0)
        }
        .frame(minWidth: isSelected && showTransactions ? 110 : nil,
               minHeight: 50,
               maxHeight: 50)
        .padding(.leading, 22)
        .padding(.trailing, isSelected && showTransactions ? 15 : 22)
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded {
            if (card.cardType == .total) {
                return
            }
            vm.restoreActiveState(vm.previouslyActiveCardsIds)
            if (vm.previouslyActiveCardsIds.first(where: { $0 == card.id }) != nil) {
                vm.setActiveCard(card.id, value: false, multiple: true)
            } else {
                vm.setActiveCard(card.id, value: true, multiple: true)
            }
            if (vm.activeCardsIds.count > 1) {
                hideTransactions()
            }
        })
        .simultaneousGesture(TapGesture().onEnded {
            let isLastCard = vm.isLastChosenCard(card)
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.previouslyActiveCardsIds = vm.activeCardsIds
                if (vm.activeCardsIds.count > 1) {
                    vm.setActiveCard(card.id, multiple: false)
                    return
                }
                if (isSelected) {
                    if (!showTransactions && isLastCard) {
                        handleAutoScroll()
                    }
                    toggleTransaction()
                } else {
                    vm.setActiveCard(card.id)
                    handleAutoScroll()
                }
            }
        })
        .padding([.top, .bottom], 1)
        .cardBackground(isSelected, card.color.dark)
        .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
        .foregroundColor(isSelected ? .white : card.color.font)
        .contextMenu {
            if (card.cardType == .total) {
                Button(role: .destructive) {
                    withAnimation {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation {
                                vm.removeAllTransactionsInAllCards()
                            }
                        }
                    }
                } label: {
                    Text("clearAllTransactionsInEveryCard")
                    Image(systemName: "xmark.circle.fill")
                }
            } else {
                Button(role: .destructive) {
                    withAnimation {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation {
                                vm.removeAllTransactions(of: card)
                            }
                        }
                    }
                } label: {
                    Text("clearAllTransactions")
                    Image(systemName: "xmark.circle.fill")
                }
            }
            Button(role: .destructive) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation {
                        vm.setCardChosen(card.id, false)
                    }
                }
            } label: {
                Text("removeFromSession")
                Image(systemName: "rectangle.stack.fill.badge.minus")
            }
            Divider()
            ShareLink(item: vm.sumString(of: card)) {
                Label("shareResult", systemImage: "123.rectangle.fill")
            }
            Divider()
            Button {
                withAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation {
                            showEditCardSheet = true
                        }
                    }
                }
            } label: {
                Text("editCard")
                Image(systemName: "pencil.circle.fill")
            }
            Divider()
            if (card.isActive && vm.activeCardsIds.count > 1 && card.cardType != .total) {
                Button {
                    withAnimation {
                        vm.setActiveCard(card.id, value: false, multiple: true)
                    }
                } label: {
                    Text("setToInactive")
                    Image(systemName: "rectangle.fill.badge.minus")
                }
            }
            if (!card.isActive && card.cardType != .total) {
                Button {
                    withAnimation {
                        vm.setActiveCard(card.id, value: true, multiple: true)
                    }
                } label: {
                    Text("addToActive")
                    Image(systemName: "rectangle.fill.badge.plus")
                }
            }
        }
    }
    
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            TransactionsCard
                .frame(maxWidth: card.isActive && showTransactions ? nil : 0)
                .padding(.horizontal, 10)
            SingleCard
        }
    }
}
