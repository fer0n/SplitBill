import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.undoManager) var undoManager
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var alerter: Alerter
    @StateObject var cvm = ContentViewModel()

    @State var showScanner: Bool = false
    @State var showEditCardSheet: Bool = false
    @State var showImagePicker: Bool = false
    @State var showSettings: Bool = false
    @State var isLoadingReplacingImage: Bool = false

    @State var showReplaceImageAlert: Bool = false
    @State var replacingImage: UIImage?
    @State var replacingImageIsHeic: Bool?

    @State private var settingsDetent: PresentationDetent = .medium

    @AppStorage("startupItem") var startupItem: StartupItem = .scanner

    let zoomBufferPadding: CGFloat = 500

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

    var liveTextImage: some View {
        ZoomableScrollView(contentPadding: zoomBufferPadding,
                           ignoreTapsAt: self.ignoreTapsAt,
                           onGestureHasBegun: self.onGestureHasBegun,
                           contentChanged: cvm.contentChanged) {
            ZStack {
                LiveTextInteraction(cvm: cvm)
                FloatingTransactionView(cvm: cvm)
            }
            .padding(zoomBufferPadding)
            .overlay(
                Rectangle()
                    .stroke(Color.backgroundColor, lineWidth: 10)
            )
            .background(Color.backgroundColor)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if cvm.chosenNormalCards.isEmpty {
                    showEditCardSheet = true
                }
            }
        }
    }

    var selectImageView: some View {
        VStack {
            Spacer()
                .frame(height: 40)
            Button {
                self.showImagePicker = true
            } label: {
                Image(systemName: "photo.fill.on.rectangle.fill")
                Spacer()
                Text("selectImage")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding([.vertical], 10)
            .padding([.horizontal], 15)
            .frame(maxWidth: .infinity)
            .background(.white)
            .foregroundColor(Color.mainColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                self.showScanner = true
            } label: {
                Image(systemName: "doc.viewfinder.fill")
                Spacer()
                Text("openScanner")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding([.vertical], 10)
            .padding([.horizontal], 15)
            .frame(maxWidth: .infinity)
            .background(.white)
            .foregroundColor(Color.mainColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .fixedSize()
    }

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            ZStack {
                if cvm.image != nil {
                    liveTextImage
                        .ignoresSafeArea()
                        .onAppear {
                            if cvm.normalCards.count <= 0 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    self.showEditCardSheet = true
                                }
                            }
                        }
                } else {
                    selectImageView
                }
                if isLoadingReplacingImage {
                    ProgressView()
                        .padding(.bottom, 100)
                }
                ButtonsOverlayView(cvm: cvm,
                                   showImagePicker: $showImagePicker,
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
        .sheet(isPresented: $showEditCardSheet) {
            // Workaround: in iOS 17, having a List { TextField(...) } breaks the partial sheet
            // A partial sheet can be used again if/once this gets fixed by Apple
            NavigationStack {
                EditCardsView(cvm: cvm)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showEditCardSheet = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }
                    .navigationTitle("editCards")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(cvm: cvm)
                .presentationDetents(
                    [.medium, .large], selection: $settingsDetent
                )
                .ignoresSafeArea()
        }
        .onChange(of: undoManager) { newManager in
            cvm.undoManager = newManager
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
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if !cvm.savedImageIsPreserved() {
                    _ = handleStoredImage()
                }
            } else if newPhase == .background {
                cvm.handleSaveState()
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
}
