//
//  CardTapInteractionModifier.swift
//  SplitBill
//
//  Created by fer0n on 29.03.25.
//

import SwiftUI

struct CardTapInteractionModifier: ViewModifier {
    @EnvironmentObject var cvm: ContentViewModel
    @Binding var showTransactions: Bool

    let card: Card
    let isSelected: Bool
    var toggleTransaction: () -> Void
    let handleAutoScroll: () -> Void

    @State var dragCancelled = false
    @State var lastTapTime: Date?

    func body(content: Content) -> some View {
        content
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        handleDoubleTap()
                    }
                    .simultaneously(with: TapGesture(count: 1)
                                        .onEnded {
                                            handleSingleTap()
                                        }
                    )
            )
    }

    func hideTransactions() {
        if showTransactions {
            toggleTransaction()
        }
    }

    func handleSingleTap() {
        let isLastCard = cvm.isLastChosenCard(card)
        withAnimation(.easeInOut(duration: 0.2)) {
            cvm.previouslyActiveCardsIds = cvm.activeCardsIds
            if cvm.activeCardsIds.count > 1 {
                cvm.setActiveCard(card.id, multiple: false)
                return
            }
            if isSelected {
                if !showTransactions && isLastCard {
                    handleAutoScroll()
                }
                toggleTransaction()
            } else {
                cvm.setActiveCard(card.id)
                handleAutoScroll()
            }
        }
    }

    func handleDoubleTap() {
        if card.cardType == .total {
            return
        }
        cvm.restoreActiveState(cvm.previouslyActiveCardsIds)
        if cvm.previouslyActiveCardsIds.first(where: { $0 == card.id }) != nil {
            cvm.setActiveCard(card.id, value: false, multiple: true)
        } else {
            cvm.setActiveCard(card.id, value: true, multiple: true)
        }
        if cvm.activeCardsIds.count > 1 {
            hideTransactions()
        }
    }
}

extension View {
    func cardTapInteraction(
        showTransactions: Binding<Bool>,
        card: Card,
        isSelected: Bool,
        toggleTransaction: @escaping () -> Void,
        handleAutoScroll: @escaping () -> Void
    ) -> some View {
        self.modifier(
            CardTapInteractionModifier(
                showTransactions: showTransactions,
                card: card,
                isSelected: isSelected,
                toggleTransaction: toggleTransaction,
                handleAutoScroll: handleAutoScroll
            )
        )
    }
}
