import Foundation
import SwiftUI

struct ButtonsOverlayView: View {
    @Environment(\.undoManager) var undoManager
    @AppStorage("successfulUserActionCount") var successfulUserActionCount: Int = 0
    @EnvironmentObject var cvm: ContentViewModel
    @Binding var showImagePicker: Bool
    @Binding var showScanner: Bool
    @Binding var showSettings: Bool
    @Binding var showEditCardSheet: Bool
    @State var showDeleteImageAlert = false

    @State var hasBeenSubtracted = false
    var showCardsView: Bool = false

    let size: CGFloat = 45

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
            .padding(.horizontal)
            Spacer()
            if showCardsView {
                CardsView(showEditCardSheet: $showEditCardSheet)
            }
        }
    }

    var menuWithOptions: some View {
        Menu {
            Button(role: .destructive) {
                showDeleteImageAlert = true
            } label: {
                Label("clearImage", systemImage: "trash.fill")
            }
            .disabled(cvm.image == nil)

            Divider()

            Button {
                showScanner = true
                handleSuccessfulUserActionCount()
            } label: {
                Label("documentScanner", systemImage: "doc.viewfinder.fill")
            }
            Button {
                showImagePicker = true
                handleSuccessfulUserActionCount()
            } label: {
                Label("photoLibrary", systemImage: "photo.fill.on.rectangle.fill")
            }
            Divider()

            Menu {
                let img = ImageModel(getImage: getImageWithAnnotations)
                ShareLink(item: img, preview: SharePreview(
                    "shareImage",
                    image: img
                )) {
                    Text("shareImage")
                }
                ShareLink(item: cvm.getChosenCardSummary(of: cvm.chosenCards)) {
                    Text("shareSummary")
                }
            } label: {
                Label("share", systemImage: "square.and.arrow.up.fill")
            }
            .disabled(cvm.image == nil)
            .onAppear {
                successfulUserActionCount += 1
            }

            Button {
                showSettings = true
            } label: {
                Label("settings", systemImage: "gearshape.fill")
            }
        } label: {
            Image(systemName: isLoading
                    ? "progress.indicator"
                    : "doc.viewfinder.fill")
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .myGlassEffect()
        }
        .foregroundColor(Color.foregroundColor)
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
            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    withAnimation {
                        undoManager?.undo()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: size, height: size)
                        .foregroundColor(Color.foregroundColor.opacity(undoDisabled ? 0.3 : 1))
                        .animation(nil, value: UUID())
                }
                .myGlassEffect(interactive: true)
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
                            .frame(width: size, height: size)
                    }
                    .myGlassEffect(interactive: true)
                    .animation(nil, value: UUID())
                }
            }
        )
    }

    var isLoading: Bool {
        cvm.isLoadingCounter != 0
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
