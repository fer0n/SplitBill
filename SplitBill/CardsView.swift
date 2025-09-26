import SwiftUI

struct CardsView: View {
    @EnvironmentObject var cvm: ContentViewModel
    @State var showCardTransactions = false
    @Binding var showEditCardSheet: Bool

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.horizontal) {
                cardsList(scrollView)
            }
            .scrollIndicators(.hidden)
        }
    }

    func cardsList(_ scrollView: ScrollViewProxy) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            addCardsButton
            CardSpacer()
            ForEach(cvm.chosenNormalCards, id: \.self) { card in
                singleCardListItem(card, scrollView: scrollView)
            }
            if !cvm.specialCards.isEmpty {
                CardSpacer()
                if cvm.totalCard?.isChosen ?? false {
                    singleCardListItem(cvm.totalCard!, scrollView: scrollView)
                        .id(cvm.totalCard)
                }
            }
        }
        .padding([.leading, .trailing], 15)
        .padding(.bottom, 12)
    }

    func handleAutoScroll(_ scrollView: ScrollViewProxy, card: Card) {
        scrollView.scrollTo(card, anchor: .center)
    }

    func toggleTransactions() {
        showCardTransactions.toggle()
    }

    func singleCardListItem(_ card: Card, scrollView: ScrollViewProxy) -> some View {
        SingleCardView(showTransactions: $showCardTransactions,
                       showEditCardSheet: $showEditCardSheet,
                       card: card,
                       isSelected: card.isActive || cvm.isActiveCard(card),
                       toggleTransaction: toggleTransactions,
                       handleAutoScroll: { handleAutoScroll(scrollView, card: card) })
            .transition(.scale)
    }

    var addCardsButton: some View {
        Button {
            showEditCardSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .fontWeight(.bold)
        }
        .frame(width: 50, height: 50)
        .cardBackground(false, .black, in: .circle)
    }
}

struct CardSpacer: View {
    var body: some View {
        Spacer()
            .frame(width: 5, height: 5)
    }
}

#Preview {
    @Previewable @State var cvm = ContentViewModel.preview

    CardsView(
        showEditCardSheet: .constant(
            false
        )
    )
    .background(.black)
    .environmentObject(ContentViewModel())
}
