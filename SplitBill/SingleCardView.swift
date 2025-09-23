//
//  SingleCardView.swift
//  SplitBill
//
//  Created by fer0n on 19.08.23.
//

import SwiftUI

// NEXT: split the transaction card into its own view
// maybe the contextmenu as well

struct SingleCardView: View {
    @ObservedObject var cvm: ContentViewModel
    @Binding public var showTransactions: Bool
    @Binding public var showEditCardSheet: Bool
    var card: Card
    var toggleTransaction: () -> Void
    let isSelected: Bool
    let handleAutoScroll: () -> Void

    init(cvm: ContentViewModel,
         showTransactions: Binding<Bool>,
         showEditCardSheet: Binding<Bool>,
         card: Card,
         toggleTransaction: @escaping () -> Void,
         handleAutoScroll: @escaping () -> Void) {
        self.cvm = cvm
        self._showTransactions = showTransactions
        self.card = card
        self.toggleTransaction = toggleTransaction
        self.isSelected = card.isActive || cvm.isActiveCard(card)
        self.handleAutoScroll = handleAutoScroll
        self._showEditCardSheet = showEditCardSheet
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            transactionsCard
                .frame(maxWidth: card.isActive && showTransactions ? nil : 0)
                .padding(.horizontal, 10)
            singleCard
        }
    }

    var transactionsCard: some View {
        VStack(alignment: .center, spacing: 0) {
            if !(showTransactions && isSelected) {
                Spacer()
                    .frame(height: 20)
            } else if card.transactionIds.count > 0 {
                TransactionsList(cvm: cvm, card: card, isSelected: isSelected)
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

    var singleCard: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: isSelected && showTransactions ? .leading : .center, spacing: 0) {
                Text("\(cvm.sumString(of: card))")
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Text("\(card.stringName)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            }
            if isSelected && showTransactions {
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
        .cardTapInteraction(
            cvm: cvm,
            showTransactions: $showTransactions,
            card: card,
            isSelected: isSelected,
            toggleTransaction: toggleTransaction,
            handleAutoScroll: handleAutoScroll
        )
        .padding([.top, .bottom], 1)
        .cardBackground(isSelected, card.color.dark, in: clipShape)
        .foregroundColor(isSelected ? .white : card.color.font)
        .contextMenu {
            if card.cardType == .total {
                Button(role: .destructive) {
                    withAnimation {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation {
                                cvm.removeAllTransactionsInAllCards()
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
                                cvm.removeAllTransactions(of: card)
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
                        cvm.setCardChosen(card.id, false)
                    }
                }
            } label: {
                Text("removeFromSession")
                Image(systemName: "rectangle.stack.fill.badge.minus")
            }
            Divider()
            ShareLink(item: cvm.sumString(of: card)) {
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
            if card.isActive && cvm.activeCardsIds.count > 1 && card.cardType != .total {
                Button {
                    withAnimation {
                        cvm.setActiveCard(card.id, value: false, multiple: true)
                    }
                } label: {
                    Text("setToInactive")
                    Image(systemName: "rectangle.fill.badge.minus")
                }
            }
            if !card.isActive && card.cardType != .total {
                Button {
                    withAnimation {
                        cvm.setActiveCard(card.id, value: true, multiple: true)
                    }
                } label: {
                    Text("addToActive")
                    Image(systemName: "rectangle.fill.badge.plus")
                }
            }
        }
    }

    private var clipShape: some Shape {
        RoundedRectangle(cornerRadius: 50, style: .continuous)
    }
}

#Preview {
    SingleCardView(cvm: ContentViewModel(),
                   showTransactions: .constant(false),
                   showEditCardSheet: .constant(false),
                   card: Card(name: "Daniel"),
                   toggleTransaction: { },
                   handleAutoScroll: { })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            HStack(spacing: 0) {
                Color.black
                Color.white
            }
        }
}
