import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import StoreKit

struct ContentView: View {
    @AppStorage("startupItem") var startupItem: StartupItem = .scanner
    @AppStorage("successfulUserActionCount") var successfulUserActionCount: Int = 0

    @Environment(\.undoManager) var undoManager
    @Environment(\.scenePhase) var scenePhase
    @Environment(Alerter.self) var alerter
    @Environment(\.requestReview) var requestReview
    @EnvironmentObject var cvm: ContentViewModel

    @State var showScanner: Bool = false
    @State var showEditCardSheet: Bool = false
    @State var showImagePicker: Bool = false
    @State var showSettings: Bool = false
    @State var isLoadingReplacingImage: Bool = false

    @State var showReplaceImageAlert: Bool = false
    @State var replacingImage: UIImage?
    @State var replacingImageIsHeic: Bool?

    let zoomBufferPadding: CGFloat = 500

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()

            ZStack {
                if cvm.image != nil {
                    LiveTextImage(showEditCardSheet: $showEditCardSheet, zoomBufferPadding: zoomBufferPadding)
                        .ignoresSafeArea()
                        .onAppear {
                            if cvm.normalCards.count <= 0 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    self.showEditCardSheet = true
                                }
                            }
                        }
                } else {
                    SelectImageView(showImagePicker: $showImagePicker, showScanner: $showScanner)
                }
                if isLoadingReplacingImage {
                    ProgressView()
                        .padding(.bottom, 100)
                }

                BlurTop()

                ButtonsOverlayView(showImagePicker: $showImagePicker,
                                   showScanner: $showScanner,
                                   showSettings: $showSettings,
                                   showEditCardSheet: $showEditCardSheet,
                                   showCardsView: cvm.image != nil)
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView(completion: { image in
                if let image = image {
                    cvm.changeImage(image)
                    cvm.clearAllTransactionsAndHistory()
                }
                self.showScanner = false
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: .photoLibrary) { image, isHeic  in
                cvm.changeImage(image, isHeic)
                cvm.clearAllTransactionsAndHistory()
            }
            .ignoresSafeArea()
        }
        .editCardsSheet(show: $showEditCardSheet)
        .settingsSheet(show: $showSettings)
        .onChange(of: undoManager) {
            cvm.undoManager = undoManager
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification), perform: { _ in
            cvm.handleSaveState()
        })
        .onAppear {
            cvm.undoManager = undoManager
            cvm.alerter = self.alerter
            cvm.onTransactionTap = self.handleTransactionTap
            handleOpenOnStart()
        }
        .onOpenURL { _ in
            self.isLoadingReplacingImage = true
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                if !cvm.savedImageIsPreserved() {
                    _ = handleStoredImage()
                }
            } else if scenePhase == .background {
                cvm.handleSaveState()
            }
        }
        .onChange(of: successfulUserActionCount) {
            let limit = 5
            if successfulUserActionCount > limit {
                Task {
                    do {
                        try await Task.sleep(nanoseconds: 8_000_000_000)
                        if successfulUserActionCount > limit {
                            requestReview()
                            successfulUserActionCount = 0
                        }
                    } catch {}
                }
            } else if successfulUserActionCount < 0 {
                successfulUserActionCount = 0
            }
        }
        .alert("replaceImage", isPresented: $showReplaceImageAlert) {
            Button("replaceYes") {
                if let img = replacingImage {
                    cvm.changeImage(img, replacingImageIsHeic)
                }
            }
            Button("replaceNo", role: .cancel) { }
        }
    }

    func handleOpenOnStart() {
        let isPreservation = handleStoredImage()
        if replacingImage != nil && isPreservation == false {
            // avoid opening scanner/picker if an image is loaded via extension,
            // do open it if the image was simply preserved
            return
        }

        switch startupItem {
        case .nothing:
            break
        case .scanner:
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                self.showScanner = true
            }
        case .imagePicker:
            self.showImagePicker = true
        }
    }

    func handleStoredImage() -> Bool? {
        let info = self.cvm.consumeStoredImage()
        guard let img = info.image else {
            self.isLoadingReplacingImage = false
            return nil
        }
        if cvm.image == nil {
            let hasTransactions = cvm.transactions.count > 0
            cvm.changeImage(img, info.isHeic, analyseTransactions: !hasTransactions)
        } else {
            replacingImage = info.image
            replacingImageIsHeic = info.isHeic
            showReplaceImageAlert = true
        }
        self.isLoadingReplacingImage = false
        return info.isPreservation
    }

    func handleTransactionTap(_ transaction: Transaction) {
        withAnimation {
            if !cvm.hasActiveCards { return }
            if cvm.transactionLinkedInAllActiveCards(transaction) {
                cvm.removeTransaction(transaction.id, from: cvm.activeCardsIds)
                cvm.flashTransaction(transaction.id, remove: true)
            } else {
                cvm.linkTransactionToActiveCards(transaction)
                if cvm.flashTransactionValue {
                    cvm.flashTransaction(transaction.id)
                }
            }
        }
    }

    func ignoreTapsAt(_ point: CGPoint) -> Bool {
        return cvm.lastTapWasHitting
    }

    func onGestureHasBegun() {
        cvm.emptyTapTimer?.invalidate()
    }
}

#Preview {
    ContentView()
        .environment(Alerter())
}
