import Foundation
import SwiftUI

struct ButtonsOverlayView: View {
    @AppStorage("successfulUserActionCount") var successfulUserActionCount: Int = 0
    @Binding var showImagePicker: Bool
    @Binding var showScanner: Bool
    @Binding var showSettings: Bool
    @Binding var showEditCardSheet: Bool

    @State var hasBeenSubtracted = false
    var showCardsView: Bool = false

    let size: CGFloat = 45

    var body: some View {
        VStack {
            HStack {
                HStack(alignment: .top) {
                    MenuOptionsView(
                        showScanner: $showScanner,
                        showImagePicker: $showImagePicker,
                        showSettings: $showSettings,
                        hasBeenSubtracted: $hasBeenSubtracted,
                        size: size
                    )
                    Spacer()
                    UndoRedoStackView(size: size)
                }
            }
            .foregroundColor(Color.foregroundColor)
            .padding(.horizontal)
            Spacer()
            if showCardsView {
                CardsView(showEditCardSheet: $showEditCardSheet)
            }
        }
    }

    func handleSuccessfulUserActionCount() {
        if !hasBeenSubtracted {
            successfulUserActionCount -= 1
            hasBeenSubtracted = true
        }
    }
}

#Preview {
    ButtonsOverlayView(showImagePicker: .constant(false),
                       showScanner: .constant(false),
                       showSettings: .constant(false),
                       showEditCardSheet: .constant(false),
                       showCardsView: false)
        .background(.black)
        .environmentObject(ContentViewModel())
}
