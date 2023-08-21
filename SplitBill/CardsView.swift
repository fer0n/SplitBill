

import SwiftUI



struct CardsView: View {
    @ObservedObject var vm: ContentViewModel
    @State var showCardTransactions = false
    @Binding var showEditCardSheet: Bool
    
    func handleAutoScroll(_ scrollView: ScrollViewProxy, card: Card) {
        scrollView.scrollTo(card, anchor: .center)
    }
    
    
    func toggleTransactions() {
        showCardTransactions.toggle()
    }
    
    func SingleCardListItem(_ card: Card, scrollView: ScrollViewProxy) -> some View {
        SingleCardView(vm: vm,
                       showTransactions: $showCardTransactions,
                       showEditCardSheet: $showEditCardSheet,
                       card: card,
                       toggleTransaction: toggleTransactions,
                       handleAutoScroll: { handleAutoScroll(scrollView, card: card) })
        .transition(.scale)
    }
    
    var AddCardsButton: some View {
        Button {
            showEditCardSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20))
                .fontWeight(.bold)
        }
        .frame(width: 50, height: 50)
        .cardBackground(false, .black)
        .clipShape(Circle())
    }
    
    
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 5) {
                    AddCardsButton
                    CardSpacer()
                    ForEach(vm.chosenNormalCards, id: \.self) { card in
                        SingleCardListItem(card, scrollView: scrollView)
                    }
                    if (!vm.specialCards.isEmpty) {
                        CardSpacer()
                        if (vm.totalCard?.isChosen ?? false) {
                            SingleCardListItem(vm.totalCard!, scrollView: scrollView)
                                .id(vm.totalCard)
                        }
                    }
                }
                .padding([.leading, .trailing], 15)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}



struct CardSpacer: View {
    var body: some View {
        Spacer()
            .frame(width: 5, height: 5)
    }
}



extension View {
    func cardBackground(_ isSelected: Bool, _ selectedColor: Color) -> some View {
        self
            .background(isSelected ? selectedColor : nil)
            .background(.thinMaterial)
            .background(isSelected ? Color.blue.opacity(0) : Color.black.opacity(0.3))
    }
}



