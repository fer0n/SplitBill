import Foundation
import SwiftUI

struct ButtonsOverlayView: View {
    @Environment(\.undoManager) var undoManager
    @AppStorage("successfulUserActionCount") var successfulUserActionCount: Int = 0
    @ObservedObject var cvm: ContentViewModel
    @Binding var showImagePicker: Bool
    @Binding var showScanner: Bool
    @Binding var showSettings: Bool
    @Binding var showEditCardSheet: Bool
    @State var showDeleteImageAlert = false

    @State var hasBeenSubtracted = false
    var showCardsView: Bool = false

    var menuWithOptions: some View {
        Menu {
            Button(role: .destructive) {
                showDeleteImageAlert = true
            } label: {
                Text("clearImage")
                Image(systemName: "trash.fill")
                    .padding(10)
            }.disabled(cvm.image == nil)
            Divider()

            Button {
                showScanner = true
                handleSuccessfulUserActionCount()
            } label: {
                Text("documentScanner")
                Image(systemName: "doc.viewfinder.fill")
                    .padding(10)
            }
            Button {
                showImagePicker = true
                handleSuccessfulUserActionCount()
            } label: {
                Text("photoLibrary")
                Image(systemName: "photo.fill.on.rectangle.fill")
                    .padding(10)
            }
            Divider()

            Menu {
                let img = ImageModel(getImage: getImageWithAnnotations)
                ShareLink(item: img, preview: SharePreview(
                    "shareImage",
                    image: img
                )) {
                    Label("shareImage", systemImage: "text.below.photo.fill")
                }
                ShareLink(item: cvm.getChosenCardSummary(of: cvm.chosenCards)) {
                    Label("shareSummary", systemImage: "list.number")
                }
            } label: {
                Text("share")
                Image(systemName: "square.and.arrow.up.fill")
                    .padding(10)
            }
            .disabled(cvm.image == nil)
            .onAppear {
                successfulUserActionCount += 1
            }

            Button {
                showSettings = true
            } label: {
                Text("settings")
                Image(systemName: "gearshape.fill")
                    .padding(10)
            }
        } label: {
            if cvm.isLoadingCounter != 0 {
                ProgressView()
                    .padding(10)
            } else {
                Image(systemName: "doc.viewfinder.fill")
                    .padding(10)
            }
        }
        .foregroundColor(Color.foregroundColor)
        .background(.thinMaterial)
        .clipShape(Circle())
        .alert("clearImage", isPresented: $showDeleteImageAlert) {
            Button("delete", role: .destructive) {
                cvm.clearImage()
                cvm.clearAllTransactionsAndHistory()
            }
            Button("cancel", role: .cancel) { }
        }
    }

    func handleSuccessfulUserActionCount() {
        if !hasBeenSubtracted {
            successfulUserActionCount -= 1
            hasBeenSubtracted = true
        }
    }

    func undoRedoStack() -> some View {
        let canUndo = undoManager?.canUndo ?? false
        let canRedo = undoManager?.canRedo ?? false
        let undoDisabled = canRedo && !canUndo

        return (
            VStack(alignment: .trailing, spacing: 20) {

                Button {
                    withAnimation {
                        undoManager?.undo()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .padding(10)
                        .foregroundColor(Color.foregroundColor.opacity(undoDisabled ? 0.3 : 1))
                        .animation(nil, value: UUID())
                }
                .background(.thinMaterial)
                .clipShape(Circle())
                .disabled(undoDisabled)
                .animation(nil, value: UUID())
                .opacity(canUndo || canRedo ? 1 : 0)

                if canRedo {
                    Button {
                        withAnimation {
                            undoManager?.redo()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .padding(10)
                    }
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .animation(nil, value: UUID())
                }
            }
        )
    }

    var body: some View {
        VStack {
            HStack {
                HStack(alignment: .top) {
                    menuWithOptions
                    Spacer()
                    undoRedoStack()
                }
            }
            .foregroundColor(Color.foregroundColor)
            .padding()
            Spacer()
            if showCardsView {
                CardsView(cvm: cvm, showEditCardSheet: $showEditCardSheet)
            }
        }
    }
}

struct ButtonsOverlayViewPreview: PreviewProvider {
    static var previews: some View {
        ButtonsOverlayView(cvm: ContentViewModel(),
                           showImagePicker: .constant(false),
                           showScanner: .constant(false),
                           showSettings: .constant(false),
                           showEditCardSheet: .constant(false),
                           showCardsView: false)
    }
}
