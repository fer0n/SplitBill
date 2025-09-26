//
//  MenuOptionsView.swift
//  SplitBill
//

import SwiftUI

struct MenuOptionsView: View {
    @EnvironmentObject var cvm: ContentViewModel
    @AppStorage("successfulUserActionCount") var successfulUserActionCount: Int = 0

    @Binding var showScanner: Bool
    @Binding var showImagePicker: Bool
    @Binding var showSettings: Bool
    @Binding var hasBeenSubtracted: Bool
    @State var showDeleteImageAlert = false

    var size: CGFloat

    var body: some View {
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

    var isLoading: Bool {
        cvm.isLoadingCounter != 0
    }

    func getImageWithAnnotations() async -> UIImage? {
        self.cvm.isLoadingCounter += 1
        guard let generate = cvm.generateExportImage else {
            print("vm.generateExportImage not assigned yet")
            self.cvm.isLoadingCounter -= 1
            return nil
        }
        do {
            guard let image = try await generate() else {
                throw ExportImageError.noImageFound
            }
            self.cvm.isLoadingCounter -= 1
            return image
        } catch {
            print("Error while trying to export image: \(error)")
        }
        self.cvm.isLoadingCounter -= 1
        return nil
    }
}
