

import SwiftUI



struct EditCardsView: View {
    @ObservedObject var vm: ContentViewModel
    @Binding var presentationDetent: PresentationDetent?
    @State private var newCard = ""
    
    @State private var showColorPicker = false
    @State var selectedCard: Card? = nil
    @State var selectedColor: ColorKeys? = nil
    
    func addNewCard() {
        let name = newCard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count > 0 else { return }
        vm.addNewCard(name)
        newCard = ""
    }
    
    func deleteCard(at index: IndexSet) {
        vm.deleteCards(at: index)
    }
    
    func setNewColor(card: Card, color: ColorKeys) {
        vm.setCardColor(card, color: color)
    }
    
    func move(from source: IndexSet, to destination: Int) {
        vm.moveNormalCard(from: source, to: destination)
    }
    
    func CardListItem(_ card: Binding<Card>, disableEdit: Bool = false) -> some View {
        HStack {
            (
                card.wrappedValue.isChosen
                    ? Image(systemName: "checkmark.circle.fill")
                    : Image(systemName: "circle")
            )
            .imageScale(.large)
            .onTapGesture {
                vm.toggleChosen(card.id)
            }

            TextField(card.name.wrappedValue, text: card.name)
                .disabled(disableEdit)
                .onChange(of: card.wrappedValue.name, perform: { _ in
                    vm.saveCardDataDebounced()
                })
                .submitLabel(.done)
        
            Spacer()
            if (!disableEdit) {
                Circle()
                    .strokeBorder(card.wrappedValue.color.font, lineWidth: 1)
                    .background(Circle().foregroundColor(card.wrappedValue.color.dark))
                    .frame(width: 25, height: 25)
                    .onTapGesture {
                        selectedCard = card.wrappedValue
                        selectedColor = card.wrappedValue.colorKey
                        showColorPicker = true
                        presentationDetent = .large
                    }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
            return 0
        }
    }
    
    
    var body: some View {
        List {
            Section {
                TextField("newCard", text: $newCard)
                    .submitLabel(.done)
                    .onSubmit(addNewCard)
                
                ForEach(vm.normalCards.indices, id: \.self) { i in
                    CardListItem($vm.normalCards[i])
                    .id(vm.normalCards[i].id)
                }
                .onDelete(perform: deleteCard)
                .onMove(perform: move)
            }
            
            Section(header: Text("specialCard")) {
                if (vm.totalCard != nil) {
                    CardListItem(Binding($vm.totalCard)!, disableEdit: true)
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            CustomColorPicker(isPresented: $showColorPicker,
                              card: $selectedCard,
                              selectedColor: $selectedColor,
                              setNewColor: setNewColor)
        }
    }
}


struct CustomColorPicker: View {
    @Binding var isPresented: Bool
    @Binding var card: Card?
    @Binding var selectedColor: ColorKeys?
    
    var setNewColor: (_ card: Card, _ color: ColorKeys) -> Void
    
    let colors = ColorKeys.allCases
    
    func singleColor(_ key: ColorKeys) -> some View {
        ZStack {
            Circle()
                .strokeBorder(CardColor.get(key).font, lineWidth: 1)
                .background(Circle().foregroundColor(CardColor.get(key).dark))
                .frame(width: 50, height: 50)
                .onTapGesture {
                    if let c = card {
                        setNewColor(c, key)
                    }
                    isPresented = false
                }
                if (selectedColor == key) {
                    Image(systemName: "checkmark")
                }
        }
    }
    
    var colorSelection: some View {
        Grid {
            GridRow {
                ForEach(0..<4) { i in
                    singleColor(colors[i])
                }
            }
            GridRow {
                ForEach(4..<8) { i in
                    singleColor(colors[i])
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            colorSelection
                .padding(.vertical, 40)
        }
        .presentationDetents([.height(250)])
    }
    
}
