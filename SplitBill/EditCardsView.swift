import SwiftUI

struct EditCardsView: View {
    @ObservedObject var cvm: ContentViewModel
    @State private var newCard = ""

    var body: some View {
        List {
            Section {
                TextField("newCard", text: $newCard)
                    .submitLabel(.done)
                    .onSubmit(addNewCard)

                ForEach(cvm.normalCards.indices, id: \.self) { index in
                    CardListItem(card: $cvm.normalCards[index], cvm: cvm)
                        .id(cvm.normalCards[index].id)
                }
                .onDelete(perform: deleteCard)
                .onMove(perform: move)
            }

            Section(header: Text("specialCard")) {
                if cvm.totalCard != nil {
                    CardListItem(card: Binding($cvm.totalCard)!, cvm: cvm, disableEdit: true)
                }
            }
        }
    }

    func addNewCard() {
        let name = newCard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count > 0 else { return }
        cvm.addNewCard(name)
        newCard = ""
    }

    func deleteCard(at index: IndexSet) {
        cvm.deleteCards(at: index)
    }

    func move(from source: IndexSet, to destination: Int) {
        cvm.moveNormalCard(from: source, to: destination)
    }
}
