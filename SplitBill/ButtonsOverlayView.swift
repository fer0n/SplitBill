

import Foundation
import SwiftUI



struct ButtonsOverlayView: View {
    @Environment(\.undoManager) var undoManager
    @ObservedObject var vm: ContentViewModel
    @Binding var showImagePicker: Bool
    @Binding var showScanner: Bool
    @Binding var showSettings: Bool
    @Binding var showEditCardSheet: Bool
    @State var showDeleteImageAlert = false
    var showCardsView: Bool = false
    
    
    var MenuWithOptions: some View {
        Menu {
            if (vm.image != nil) {
                Button(role: .destructive) {
                    showDeleteImageAlert = true
                } label: {
                    Text("clearImage")
                    Image(systemName: "trash.fill")
                        .padding(10)
                }
                Divider()
            }
            
            Button {
                showScanner = true
            } label: {
                Text("documentScanner")
                Image(systemName: "doc.viewfinder.fill")
                    .padding(10)
            }
            Button {
                showImagePicker = true
            } label: {
                Text("photoLibrary")
                Image(systemName: "photo.fill.on.rectangle.fill")
                    .padding(10)
            }
            Divider()
            Button {
                showSettings = true
            } label: {
                Text("settings")
                Image(systemName: "gearshape.fill")
                    .padding(10)
            }
        } label: {
            Image(systemName: "doc.viewfinder.fill")
                .padding(10)
        }
        .foregroundColor(Color.foregroundColor)
        .background(.thinMaterial)
        .clipShape(Circle())
        .alert("clearImage", isPresented: $showDeleteImageAlert) {
            Button("delete", role: .destructive) {
                vm.clearImage()
                vm.clearAllTransactionsAndHistory()
            }
            Button("cancel", role: .cancel) { }
        }
    }
    
    func UndoRedoStack() -> some View {
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
                
                if (canRedo) {
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
                    MenuWithOptions
                    Spacer()
                    UndoRedoStack()
                }
            }
            .foregroundColor(Color.foregroundColor)
            .padding()
            Spacer()
            if (showCardsView) {
                CardsView(vm: vm, showEditCardSheet: $showEditCardSheet)
            }
        }
    }
}

struct Previews_ButtonsOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonsOverlayView(vm: ContentViewModel(),
                           showImagePicker: .constant(false),
                           showScanner: .constant(false),
                           showSettings: .constant(false),
                           showEditCardSheet: .constant(false),
                           showCardsView: false)
    }
}
