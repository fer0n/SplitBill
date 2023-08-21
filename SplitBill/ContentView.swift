

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers



struct ContentView: View {
    @Environment(\.undoManager) var undoManager
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var alerter: Alerter
    @StateObject var vm = ContentViewModel()
    
    @State var showScanner: Bool = false
    @State var showEditCardSheet: Bool = false
    @State var showImagePicker: Bool = false
    @State var showSettings: Bool = false
    @State var isLoadingReplacingImage: Bool = false
    
    @State var showReplaceImageAlert: Bool = false
    @State var replacingImage: UIImage? = nil
    @State var replacingImageIsHeic: Bool? = nil
    
    @State private var presentationDetent: PresentationDetent? = nil
    @State private var settingsDetent: PresentationDetent = .medium

    let zoomBufferPadding: CGFloat = 500
        
    
    func handleOpenOnStart() {
        let isPreservation = handleStoredImage()
        if (replacingImage != nil && isPreservation == false) {
            // avoid opening scanner/picker if an image is loaded via extension, do open it if the image was simply preserved
            return
        }
        
        switch(vm.startupItem) {
            case .nothing:
                break
            case .scanner:
                if (AVCaptureDevice.authorizationStatus(for: .video) == .authorized) {
                    self.showScanner = true
                }
                break
            case .imagePicker:
                self.showImagePicker = true
                break
        }
    }
    
    
    func handleStoredImage() -> Bool? {
        
        let (imageFromExtension, isHeic, isPreservation) = self.vm.consumeStoredImage()
        guard let img = imageFromExtension else {
            self.isLoadingReplacingImage = false
            return nil
        }
        if (vm.image == nil) {
            let hasTransactions = vm.transactions.count > 0
            vm.changeImage(img, isHeic, analyseTransactions: !hasTransactions)
        } else {
            replacingImage = imageFromExtension
            replacingImageIsHeic = isHeic
            showReplaceImageAlert = true
        }
        self.isLoadingReplacingImage = false
        return isPreservation
    }


    func handleTransactionTap(_ transaction: Transaction) {
        withAnimation {
            if (!vm.hasActiveCards) { return }
            if (vm.transactionLinkedInAllActiveCards(transaction)) {
                vm.removeTransaction(transaction.id, from: vm.activeCardsIds)
            } else {
                if (vm.flashTransactionValue) {
                    vm.flashTransaction(transaction)
                }   
                vm.linkTransactionToActiveCards(transaction)
            }
        }
    }
    
    
    func ignoreTapsAt(_ point: CGPoint) -> Bool {
        return vm.lastTapWasHitting
    }
    

    var LiveTextImage: some View {
        ZoomableScrollView(contentPadding: zoomBufferPadding, ignoreTapsAt: self.ignoreTapsAt, contentChanged: vm.contentChanged) {
            ZStack {
                LiveTextInteraction(vm: vm)
                FloatingTransactionView(vm: vm)
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
                if (vm.chosenNormalCards.isEmpty) {
                    showEditCardSheet = true
                }
            }
        }
    }
    
    var SelectImageView: some View {
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
                if (vm.image != nil) {
                    LiveTextImage
                        .ignoresSafeArea()
                        .onAppear {
                            if (vm.normalCards.count <= 0) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    self.showEditCardSheet = true
                                }
                            }
                        }
                } else {
                   SelectImageView
                }
                if (isLoadingReplacingImage) {
                    ProgressView()
                        .padding(.bottom, 100)
                }
                ButtonsOverlayView(vm: vm,
                                   showImagePicker: $showImagePicker,
                                   showScanner: $showScanner,
                                   showSettings: $showSettings,
                                   showEditCardSheet: $showEditCardSheet,
                                   showCardsView: vm.image != nil)
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerView(completion: { image in
                if let image = image {
                    vm.changeImage(image)
                    vm.clearAllTransactionsAndHistory()
                }
                self.showScanner = false
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: .photoLibrary) { image, isHeic  in
                vm.changeImage(image, isHeic)
                vm.clearAllTransactionsAndHistory()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showEditCardSheet) {
            let detents: Set<PresentationDetent> = !vm.hasNormalCards ? [.small, .medium, .large] : [.medium, .large]
            EditCardsView(vm: vm, presentationDetent: $presentationDetent)
                .presentationDetents(
                    detents, selection: Binding($presentationDetent) ?? .constant(!vm.hasNormalCards ? .small : .medium)
                 )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(vm: vm,
                         showSelf: $showSettings)
                .presentationDetents(
                    [.medium, .large], selection: $settingsDetent
                 )
                .ignoresSafeArea()
        }
        .onChange(of: undoManager) { newManager in
            vm.undoManager = newManager
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification), perform: { _ in
            vm.handleAppWillTerminate()
         })
        .onAppear {
            vm.undoManager = undoManager
            vm.alerter = self.alerter
            vm.onTransactionTap = self.handleTransactionTap
            handleOpenOnStart()
        }
        .onOpenURL { _ in
            self.isLoadingReplacingImage = true
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                let _ = handleStoredImage()
            }
        }
        .alert("replaceImage", isPresented: $showReplaceImageAlert) {
            Button("replaceYes") {
                if let img = replacingImage {
                    vm.changeImage(img, replacingImageIsHeic)
                }
            }
            Button("replaceNo", role: .cancel) { }
        }
    }
}



