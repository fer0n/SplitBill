

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
    
    @State var floatingTransaction: Transaction? = nil
    @State var floatingTransactionValue: String = ""
    @State var floatingTransactionColor: Color = .blue
    @State var floatingTransactionContrastColor: Color = .white
    @FocusState private var floatingTransactionIsFocused: Bool
    @State var floatingTransactionDisappearTimer: Timer? = nil
    
    let zoomBufferPadding: CGFloat = 500
        
    
    func handleOpenOnStart() {
        let isPreservation = handleStoredImage()
        if (replacingImage != nil || isPreservation != true) {
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
            vm.changeImage(img, isHeic)
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
                    flashTransaction(transaction)
                }
                vm.linkTransactionToActiveCards(transaction)
            }
        }
    }
    
    func setFloatingTransactionColor(_ transaction: Transaction?) {
        let firstactiveCard = vm.getFirstActiveCard()
        if let t = transaction, let card = vm.getFirstChosencardOfTransaction(t) {
            let cards = vm.getChosencardsOfTransaction(t)
            if let firstactiveCard = firstactiveCard, cards.contains(firstactiveCard) {
                floatingTransactionColor = firstactiveCard.color.light
                floatingTransactionContrastColor = firstactiveCard.color.contrast
            } else {
                floatingTransactionColor = card.color.light
                floatingTransactionContrastColor = card.color.contrast
            }
        } else {
            floatingTransactionColor = firstactiveCard?.color.light ?? Color(vm.markerColor ?? .blue)
            floatingTransactionContrastColor = firstactiveCard?.color.contrast ?? .white
        }
    }
    
    func flashTransaction(_ t: Transaction) {
        if (vm.getFirstChosencardOfTransaction(t) != nil) {
            return
        }
        withAnimation {
            setFloatingTransactionColor(t)
            floatingTransaction = t
            floatingTransactionValue = t.stringValue
        }
        debouncedHideFloatingTransaction()
    }
    
    func debouncedHideFloatingTransaction() {
        floatingTransactionDisappearTimer?.invalidate()
        floatingTransactionDisappearTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            withAnimation {
                animationWorkaroundResetFloatingTransaction()
                floatingTransaction = nil
            }
        }
    }
    
    func animationWorkaroundResetFloatingTransaction() {
        // Workaround: for whatever reason, without this the fade out animation isn't working
        let val = (floatingTransaction?.stringValue ?? "").replacingOccurrences(of: ".", with: ",")
        floatingTransactionValue = val
    }
    
    func ignoreTapsAt(_ point: CGPoint) -> Bool {
        return vm.lastTapWasHitting
    }
    
    func handleTransactionLongPress(_ transaction: Transaction?, _ point: CGPoint?) {
        setFloatingTransactionColor(transaction)
        floatingTransactionIsFocused = true
        if let t = transaction {
            // edit existing transaction
            floatingTransaction = transaction
            floatingTransactionValue = String(t.value)
        } else {
            // new transaction
            guard let point = point else { return }
            floatingTransactionValue = ""
            floatingTransaction = Transaction(value: 0, boundingBox: CGRect(x: point.x, y: point.y, width: .zero, height: .zero))
        }
    }
    
    
    func handleFreeformTransaction() {
        withAnimation {
            if let value = Double.parse(from: floatingTransactionValue), var transaction = floatingTransaction {
                transaction.value = value
                let hitCard = vm.getFirstChosencardOfTransaction(transaction)
                if (hitCard != nil || vm.hasTransaction(transaction)) {
                    vm.correctTransaction(transaction)
                } else  {
                    let boundingBox = vm.getProposedMarkerRect(basedOn: transaction.boundingBox)
                    let t = vm.createNewTransaction(value: value, boundingBox: boundingBox)
                    vm.linkTransactionToActiveCards(t)
                }
            }
            floatingTransaction = nil
        }
    }
    
    var FloatingTransactionTextField: some View {
        TextField("", text: $floatingTransactionValue, onEditingChanged: { edit in
            if (!edit) {
                handleFreeformTransaction()
            } else {
                floatingTransactionDisappearTimer?.invalidate()
            }
        })
        .keyboardType(.numbersAndPunctuation)
        .submitLabel(.done)
        .disableAutocorrection(true)
        .onSubmit {
            handleFreeformTransaction()
        }
        .fixedSize()
        .font(.system(size: 30))
        .accentColor(.white)
        .foregroundColor(floatingTransactionContrastColor)
        .focused($floatingTransactionIsFocused)
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 1).fill(floatingTransactionColor))
        .clipShape(RoundedRectangle(cornerRadius: floatingTransaction?.boundingBox?.cornerRadius ?? 0))
        .frame(width: floatingTransaction?.boundingBox?.width, height: floatingTransaction?.boundingBox?.height)
        .position(x: (floatingTransaction?.boundingBox?.minX ?? 0) - 20 - (floatingTransaction?.boundingBox?.width ?? 0) / 2, y: floatingTransaction?.boundingBox?.midY ?? 0)
    }

    var LiveTextImage: some View {
        ZoomableScrollView(contentPadding: zoomBufferPadding, ignoreTapsAt: self.ignoreTapsAt, contentChanged: vm.contentChanged) {
            ZStack {
                LiveTextInteraction(vm: vm)
                    if (floatingTransaction != nil) {
                        FloatingTransactionTextField
                            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
                            .zIndex(1)
                    }
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
            vm.onTransactionTap = self.handleTransactionTap
            vm.onImageLongPress = self.handleTransactionLongPress
            vm.alerter = self.alerter
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


extension UIFont {
    func calculateHeight(text: String, width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: constraintRect,
                                        options: NSStringDrawingOptions.usesLineFragmentOrigin,
                                            attributes: [NSAttributedString.Key.font: self],
                                        context: nil)
        return boundingBox.height
    }
}
