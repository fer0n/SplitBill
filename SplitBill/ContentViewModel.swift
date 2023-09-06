

import Foundation
import SwiftUI
import Vision
import Combine
import SplitBillShared



class ContentViewModel: ObservableObject {    
    @Published var cards: [Card]
    @Published private(set) var activeCardsIds: Set<UUID> = []
    @Published var transactions: [UUID: Transaction] = [:]
    @Published var image: UIImage?
    @Published var contentChanged = PassthroughSubject<Void, Never>()
    @Published var isLoadingCounter: Int = 0
    
    @AppStorage("previewDuration") var previewDuration: PreviewDuration = .tapAway
    @AppStorage("flashTransactionValue") var flashTransactionValue: Bool = true
    @AppStorage("transactions") var encodedTransactions: Data?
        
    private static let cardsSaveKey = "Cards"
    
    static var totalTransactionId: UUID? = nil
    private let dividerId = UUID(uuidString: "BD89DE13-54FF-4C1D-8B45-C090858689FE")!
    private var totalCardId: UUID? = nil
    
    weak var alerter: Alerter?
    weak var undoManager: UndoManager?
    var markerColor: UIColor? = nil
    var imageIsLight: Bool = true
    var lineWidth: CGFloat? = nil
    var imageIsHeic = false
    
    var observations: [VNRecognizedTextObservation] = []
    var onTransactionTap: ((_ transaction: Transaction) -> Void)?
    var onFlashTransaction: ((_ transactionId: UUID, _ remove: Bool) -> Void)?
    var onImageLongPress: ((_ transaction: Transaction?, _ point: CGPoint?) -> Void)?
    var generateExportImage: (() async throws -> UIImage?)?
    var onEmptyTap: (() -> Void)?
    var emptyTapTimer: Timer? = nil
    
    var lastTapWasHitting = false
    var previouslyActiveCardsIds: Set<UUID> = []
    var cardsIndexLookup: [UUID: Array<Card>.Index] = [:]
    var saveCardsTimer: Timer? = nil

    
    var hasActiveCards: Bool {
        activeCardsIds.count > 0
    }
    
    var specialCards: [Card] {
        cards.filter { $0.cardType != .normal }
    }
    
    var totalCard: Card? {
        get {
            if let id = totalCardId, let index = getCardsIndex(of: id) {
                return cards[index]
            }
            return nil
        }
        set {
            guard let val = newValue else { return }
            if let id = totalCardId, let index = getCardsIndex(of: id) {
                cards[index] = val
            } else {
                appendNewCard(val)
            }
        }
    }
    
    var normalCards: [Card] {
        get {
            cards.filter { $0.cardType == .normal }
        }
        set {
            for card in newValue {
                if let index = getCardsIndex(of: card.id) {
                    cards[index] = card
                }
            }
            
        }
    }
    
    var hasNormalCards: Bool {
        cards.first(where: { $0.cardType == .normal }) != nil
    }
        
    var sortedCards: [Card] {
        normalCards.sorted { $0.isActive && !$1.isActive }
    }
    
    var chosenNormalCards: [Card] {
        cards.filter { $0.isChosen && $0.cardType == .normal }
    }
    
    var chosenCards: [Card] {
        cards.filter { $0.isChosen }
    }
    
    var transactionList: [Transaction] {
        var res: [Transaction] = []
        for (_, value) in transactions {
            res.append(value)
        }
        return res
    }
    
    var boundingBoxes: [CGRect] {
        transactionList.compactMap { tt in
            tt.boundingBox
        }
    }
    
    
    // MARK: Init
    
    init() {
        print("init contentViewModel")
        cards = ContentViewModel.getCardData()
        if let index = cards.firstIndex(where: { $0.cardType == .total }) {
            totalCardId = cards[index].id
        } else {
            var totalCard = Card(.total)
            totalCard.isChosen = true
            appendNewCard(totalCard)
            totalCardId = totalCard.id
        }
        updateCardsIndexLookup()
        setFirstChosenCardActive()
        self.getTransactionData()
    }
    
    
    // MARK: Functions
    
    func updateCardsIndexLookup() {
        var lookup: [UUID:Array<Card>.Index] = [:]
        for i in cards.indices {
            lookup[cards[i].id] = i
        }
        cardsIndexLookup = lookup
    }
    
    func handleSaveState() {
        saveCardData()
        saveImageData()
        saveTransactionData()
    }
    
    func saveTransactionData() {
        if let encoded = try? JSONEncoder().encode(transactions) {
            encodedTransactions = encoded
            print("Saving transactions: \(encoded)")
        }
    }
    
    func saveImageData() {
        if let img = self.image {
            do {
                let _ = try saveImageDataToSplitBill(img, isHeic: self.imageIsHeic, isPreservation: true)
            } catch {
                print("error saving image: \(error)")
            }
        }
    }
    
    func addNewCard(_ name: String) {
        var newCard = Card(name: name)
        newCard.isChosen = true
        newCard.colorKey = getRarestColor()
        cards.insert(newCard, at: 0)
        saveCardDataDebounced()
        ensureActiveCardExists()
    }
    
    func getRarestColor() -> ColorKeys {
        var colorDict: [ColorKeys: Int] = [:]
        for c in ColorKeys.allCases {
            colorDict[c] = 0
        }
        for card in cards {
            colorDict[card.colorKey] = (colorDict[card.colorKey] ?? 0) + 1
        }
        var rarest = ColorKeys.neutralDark
        var min = colorDict[ColorKeys.neutralDark] ?? cards.count
        for (colorKey, amount) in colorDict {
            if (amount < min) {
                rarest = colorKey
                min = amount
            }
        }
        return rarest
    }
    
    func appendNewCard(_ newCard: Card) {
        cards.append(newCard)
        saveCardDataDebounced()
    }
        
    func  consumeStoredImage() -> (image: UIImage?, isHeic: Bool?, isPreservation: Bool?) {
        let (loadedImage, isHeic, isPreservation) = loadImage()
        guard let img = loadedImage else {
            return (nil, nil, nil)
        }
        resetStoredImage()
        return (img, isHeic, isPreservation)
    }
    
    func savedImageIsPreserved() -> Bool {
        let userDefaults = UserDefaults(suiteName: "group.splitbill")
        return userDefaults?.bool(forKey: "imageIsPreserved") == true
    }
    
    func loadImage() -> (image: UIImage?, isHeic: Bool?, isPreservation: Bool?) {
        let userDefaults = UserDefaults(suiteName: "group.splitbill")
        guard let data = userDefaults?.data(forKey: "imageData") else {
            return (nil, nil, nil)
        }
        let decoded = try! PropertyListDecoder().decode(Data.self, from: data)
        let isHeic = userDefaults?.bool(forKey: "isHeic")
        let isPreservation = savedImageIsPreserved()
        let image = UIImage(data: decoded)
        return (image, isHeic, isPreservation)
    }
    
    func resetStoredImage() {
        let userDefaults = UserDefaults(suiteName: "group.splitbill")
        userDefaults?.removeObject(forKey: "imageData")
    }
    
    func clearImage() {
        image = nil
    }
    
    func getTransactionData() {
        if let data = encodedTransactions {
            if let decoded = try? JSONDecoder().decode([UUID: Transaction].self, from: data) {
                transactions = decoded
            }
        }
    }
    
    static func getCardData() -> [Card] {
        if let data = UserDefaults.standard.data(forKey: ContentViewModel.cardsSaveKey) {
            if let decoded = try? JSONDecoder().decode([Card].self, from: data) {
                return decoded
            }
        }
        return []
    }
    
    func saveCardDataDebounced() {
        self.updateCardsIndexLookup()
        saveCardsTimer?.invalidate()
        saveCardsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            DispatchQueue.main.async {
                self.saveCardData()
            }
        }
    }
    
    func saveCardData() {
        if let encoded = try? JSONEncoder().encode(self.cards) {
            UserDefaults.standard.set(encoded, forKey: ContentViewModel.cardsSaveKey)
        }
    }
    
    func createNewTransaction(_ transaction: Transaction) {
        changeTransaction(transaction.id, transaction)
    }
    
    func createNewTransaction(value: Double, boundingBox: CGRect) -> Transaction {
        let t = Transaction(value: value, boundingBox: boundingBox, transactionType: .freeForm)
        createNewTransaction(t)
        return t
    }
        
    func linkTransactionToActiveCards(_ transaction: Transaction) {
        for cardId in activeCardsIds {
            linkTransaction(cardId, transactionId: transaction.id)
        }
    }
    
    func linkTransaction(_ card: Card, value: Double, boundingBox: CGRect) {
        let t = Transaction(value: value, boundingBox: boundingBox, transactionType: card.cardType == .total ? .total : nil)
        linkTransaction(card.id, transactionId: t.id)
    }
    
    func totalTransactionIsInvolved(_ card: Card, _ transactionId: UUID) -> Bool {
        return (card.cardType == .total && transactions[transactionId]?.shares.count ?? 0 >= 1)
        || (card.cardType != .total && transactionId == ContentViewModel.totalTransactionId)
    }
    
    func linkTransaction(_ cardId: UUID, transactionId: UUID) {
        guard let index = getCardsIndex(of: cardId),
                transactions[transactionId] != nil,
                !cards[index].transactionIds.contains(transactionId),
                !totalTransactionIsInvolved(cards[index], transactionId) else {
            return
        }
        undoManager?.beginUndoGrouping()
        if (cardId == totalCard?.id) {
            if (transactions[transactionId]?.type != .cardSummary) {
                ContentViewModel.totalTransactionId = transactionId
            }
        }
        handleError({
            try self.transactions[transactionId]!.addShare(cardId: cardId)
        }, onSuccess: {
            self.cards[index].addTransactionId(transactionId)
            let t = self.transactions[transactionId]!
            self.addNewTransactionUndoActionRegister(for: self.cards[index], transaction: t)
            self.updateTotalValue()
        })
        undoManager?.endUndoGrouping()
    }
    
    func handleError(_ throwingFunction:  @escaping() throws -> Void, onError: (() -> Void)? = nil, onSuccess: (() -> Void)? = nil) {
        do {
            try throwingFunction()
            if let ex = onSuccess {
                ex()
            }
            return
        } catch EditShareError.lastShareCannotBeAdjustedManually {
            alerter?.alert = Alert(title: Text("cannotEditShare"), message: Text("lastShareCannotBeAdjustedManually"))
        } catch EditShareError.numberTooLarge {
            alerter?.alert = Alert(title: Text("numberTooLargeTitle"), message: Text("numberTooLargeMessage"))
        } catch {
            alerter?.alert = Alert(title: Text("unknown"))
        }
        
        if let ex = onError {
            ex()
        }
    }
    
    func updateTotalValue() {
        guard let id = totalCardId, let index = getCardsIndex(of: id), cards[index].isChosen else { return }
        let oldTransactionids = cards[index].transactionIds
        var transactionIds: [UUID] = []
        // add all nececcary transactions to the transactions list
        // & update all transactions in the transactions list
        
        // oldTransactionIds are stored and deleted in the end
        // for each card, the sum is calculated and stored as a transaction in transactions
        // the sum-transactions are then used as a transaction for the total card to display the people
        
        chosenNormalCards.forEach { card in
            let sum = sum(of: card)
            if (transactions[card.id] != nil) {
                transactions[card.id]!.rawValue = sum
            } else {
                transactions[card.id] = Transaction(value: sum, label: card.name, transactionType: .cardSummary, locked: true, id: card.id)
            }
            transactionIds.append(card.id)
        }
        
        // create a divider transaction if it doesn't exist already
        if let totalId = ContentViewModel.totalTransactionId, oldTransactionids.contains(totalId) {
            if (transactions[dividerId] == nil) {
                transactions[dividerId] = Transaction(value: 0, transactionType: .divider)
            }
            transactionIds.append(dividerId)
            transactionIds.append(totalId)
        }
        let toBeRemoved = cards[index].transactionIds.filter { !transactionIds.contains($0) }
        for t in toBeRemoved {
            removeShare(t, cards[index].id)
        }
        cards[index].transactionIds = transactionIds
    }
    
    func linkAllTransactions(_ transactionIds: [UUID], _ card: Card) {
        for tId in transactionIds {
            linkTransaction(card.id, transactionId: tId)
        }
    }
    
    func removeAllTransactions(_ transactionIds: [UUID], _ card: Card) {
        for tId in transactionIds {
            removeTransaction(tId, of: card.id)
        }
    }
    
    func removeShare(_ transactionId: UUID, _ cardId: UUID) {
        if transactions[transactionId] != nil {
            handleError({
                try self.transactions[transactionId]!.removeShare(cardId: cardId)
            })
        }
    }
    
    func transactionLinkedInAllActiveCards(_ transaction: Transaction) -> Bool {
        for cardId in activeCardsIds {
            if let index = getCardsIndex(of: cardId) {
                if (!cards[index].transactionIds.contains(transaction.id)) {
                    return false
                }
            }
        }
        return true
    }
    
    func removeTransaction(_ transactionId: UUID, from cardsIds: Set<UUID>) {
        undoManager?.beginUndoGrouping()
        for cardId in cardsIds {
            removeTransaction(transactionId, of: cardId)
        }
        undoManager?.endUndoGrouping()
    }
    
    func removeTransaction(_ transactionId: UUID, of cardId: UUID) {
        guard let index = getCardsIndex(of: cardId) else { return }
        guard let transaction = transactions[transactionId] else {
            // transaction might be stuck, remove all of them manually
            cards[index].clearTransactions()
            return
        }
        removeShare(transactionId, cardId)
        if (transactionId == ContentViewModel.totalTransactionId) {
            ContentViewModel.totalTransactionId = nil
        }
        cards[index].removeTransaction(transaction)
        removeNewTransactionUndoActionRegister(for: cards[index], transaction: transaction)
        updateTotalValue()
    }
    
    func resetShare(_ transaction: Transaction, of card: Card) {
        if transactions[transaction.id] != nil {
            handleError({
                try self.transactions[transaction.id]!.resetShare(cardId: card.id)
            })
        }
    }
    
    func removeAllTransactionsInAllCards() {
        for c in cards {
            removeAllTransactions(of: c)
        }
    }
    
    func removeAllTransactions(of card: Card) {
        undoManager?.beginUndoGrouping()
        for tId in card.transactionIds {
            removeTransaction(tId, of: card.id)
        }
        undoManager?.endUndoGrouping()
        updateTotalValue()
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        changeTransaction(transaction.id, nil)
    }
    
    func changeTransaction(_ transactionId: UUID, _ transaction: Transaction?) {
        let oldTransaction = transactions[transactionId]
        transactions[transactionId] = transaction
        changeTransactionUndoActionRegister(transactionId, oldTransaction)
    }
    
    func changeTransactionUndoActionRegister(_ oldTransactionId: UUID, _ oldTransaction: Transaction?) {
        self.undoManager?.registerUndo(withTarget: self, handler: { (selfTarget) in
            self.changeTransaction(oldTransactionId, oldTransaction)
        })
    }
    
    func addNewTransactionUndoActionRegister(for card: Card, transaction: Transaction) {
        self.undoManager?.registerUndo(withTarget: self, handler: { (selfTarget) in
            self.removeTransaction(transaction.id, of: card.id)
        })
    }
    
    func removeNewTransactionUndoActionRegister(for card: Card, transaction: Transaction) {
        self.undoManager?.registerUndo(withTarget: self, handler: { (selfTarget) in
            self.linkTransaction(card.id, transactionId: transaction.id)
        })
    }
    
    func setCardUndoActionRegister(for card: Card, isChosen: Bool) {
        self.undoManager?.registerUndo(withTarget: self, handler: { (selfTarget) in
            self.setCardChosen(card.id, isChosen)
        })
    }
    
    func setTransactionEditActionRegister(_ oldTransaction: Transaction) {
        self.undoManager?.registerUndo(withTarget: self, handler: { (selfTarget) in
            self.editTransaction(oldTransaction)
        })
    }
    
    func editTransaction(_ id: UUID, value: Double, _ card: Card? = nil) {
        guard var transaction = transactions[id] else {
            print("transaction couldn't be edited")
            return
        }
        if transaction.shares.count > 1, let cardId = card?.id, transaction.shares[cardId] != nil {
            handleError({
                try transaction.editShare(cardId: cardId, value: value)
            }, onSuccess: {
                self.editTransaction(transaction)
            })
        } else {
            transaction.value = value
            correctTransaction(transaction)
        }
    }
    
    func editTransaction(_ newTransaction: Transaction) {
        let oldTransaction: Transaction? = transactions[newTransaction.id]
        guard let oldTransaction = oldTransaction else {
            print("transaction couldn't be edited")
            return
        }
        setTransactionEditActionRegister(oldTransaction)
        self.transactions[newTransaction.id] = newTransaction
        updateTotalValue()
    }

    func clearAllTransactionsAndHistory() {
        for card in cards {
            removeAllTransactions(of: card)
        }
        undoManager?.removeAllActions()
        updateTotalValue()
    }
    
    func getChosencardsOfTransaction(_ transaction: Transaction) -> [Card] {
        var result: [Card] = []
        for card in chosenCards {
            for t in card.transactionIds {
                if (t == transaction.id) {
                    result.append(card)
                }
            }
        }
        return result
    }
    
    func getFirstChosencardOfTransaction(_ transaction: Transaction) -> Card? {
        for card in chosenCards {
            for t in card.transactionIds {
                if (t == transaction.id) {
                    return card
                }
            }
        }
        return nil
    }
    
    func setActiveCard(_ cardId: UUID, value: Bool = true, multiple: Bool = false) {
        if (activeCardsIds.count == 1 && value == false) {
            return
        }
        if (!multiple) {
            setAllCardsInactive()
        }
        guard let index = getCardsIndex(of: cardId) else { return }
        cards[index].isActive = value
        if (value == true) {
            activeCardsIds.insert(cardId)
        } else {
            activeCardsIds.remove(cardId)
        }
    }
    
    func getFirstActiveCard() -> Card? {
        guard let activeCardId = activeCardsIds.first else {
            return nil
        }
        guard let activeCardIndex = getCardsIndex(of: activeCardId) else {
            return nil
        }
        return cards[activeCardIndex]
    }
    
    func restoreActiveState(_ cardsIds: Set<UUID>) {
        setAllCardsInactive()
        for cardId in cardsIds {
            if (cardId != totalCard?.id) {
                setActiveCard(cardId, value: true, multiple: true)
            }
        }
    }
    
    func setAllCardsInactive() {
        for i in cards.indices {
            cards[i].isActive = false
        }
        activeCardsIds = []
    }
    
    func isLastChosenCard(_ card: Card) -> Bool {
        if let index = chosenCards.firstIndex(of: card),
           index == chosenCards.count - 1 {
            return true
        }
        return false
    }
    
    func setFirstChosenCardActive() {
        if let firstCard = chosenCards[safe: 0] {
            setActiveCard(firstCard.id)
        }
    }
    
    func isActiveCard(_ card: Card) -> Bool {
        return activeCardsIds.contains(card.id)
     }
    
    func moveNormalCard(from source: IndexSet, to destination: Int) {
        var translatedSet: IndexSet = []
        for i in source {
            let card = normalCards[i]
            if let index = getCardsIndex(of: card.id) {
                translatedSet.insert(index)
            }
        }
        cards.move(fromOffsets: translatedSet, toOffset: destination)
        saveCardDataDebounced()
    }
    
    func toggleChosen(_ cardId: UUID) {
        guard let index = getCardsIndex(of: cardId) else { return }
        setCardChosen(cardId, !cards[index].isChosen)
    }
    
    func setCardChosen(_ cardId: UUID, _ chosenValue: Bool) {
        guard let index = getCardsIndex(of: cardId) else { return }
        undoManager?.beginUndoGrouping()
        cards[index].isChosen = chosenValue
        if (chosenValue == false) {
            removeAllTransactions(of: cards[index])
        }
        if (chosenValue == false && cards[index].isActive) {
            setFirstChosenCardActive()
        }
        if (chosenValue == true) {
            ensureActiveCardExists()
        }
        setCardUndoActionRegister(for: cards[index], isChosen: !chosenValue)
        undoManager?.endUndoGrouping()
        saveCardDataDebounced()
    }
    
    func ensureActiveCardExists() {
        if (activeCardsIds.count == 0) {
            setFirstChosenCardActive()
        }
    }
    
    func getCardsIndex(of cardId: UUID) -> Array<Card>.Index? {
        return cardsIndexLookup[cardId]
    }
    
    func getCardCopy(of cardId: UUID) -> Card? {
        if let index = getCardsIndex(of: cardId) {
            return cards[index]
        }
        return nil
    }
    
    func setCardColor(_ card: Card, color: ColorKeys) {
        if let index = getCardsIndex(of: card.id) {
            cards[index].colorKey = color
        }
        saveCardDataDebounced()
    }
    
    func deleteCards(at indeces: IndexSet) {
        for i in indeces {
            removeAllTransactions(of: cards[i])
        }
        cards.remove(atOffsets: indeces)
        saveCardDataDebounced()
        updateTotalValue()
        setFirstChosenCardActive()
        return
    }
    
    // Transactions
    
    func getTransaction(_ id: UUID) -> Transaction? {
        let transaction = transactions[id]
        if let t = transaction, id == ContentViewModel.totalTransactionId {
            return Transaction(from: t, transactionType: .total)
        }
        return transaction
    }
    
    func correctTransaction(_ transaction: Transaction) {
        changeTransaction(transaction.id, transaction)
        handleError({
            try self.transactions[transaction.id]?.refreshShares()
        }, onSuccess: {
            self.updateTotalValue()
        })
    }
    
    func changeImage(_ image: UIImage, _ isHeic: Bool? = false, analyseTransactions: Bool = true) {
        self.isLoadingCounter += 1
        self.image = image
        self.contentChanged.send()
        self.imageIsHeic = isHeic ?? false
        
        if (analyseTransactions) {
            self.transactions = [:]
            self.processImage()
        }
        
        DispatchQueue.main.async {
            let averageColorOfImage = image.averageColor
            self.imageIsLight = averageColorOfImage?.isLight() ?? true
            self.markerColor = self.imageIsLight ? .black : .white
        }
        self.isLoadingCounter -= 1
    }
    
    func storeObservationsAsTappableText(_ observations: [VNRecognizedTextObservation]) {
        guard let image = self.image else { return }
        
        observations.forEach { observation in
            guard let candidate = observation.topCandidates(1).first else { return }
            
            let numberIndices = findNumberIndices(candidate.string)
            for (numberIndexRange, decimalPoint) in numberIndices {
                let numberStr = String(candidate.string[numberIndexRange])
                guard let number = cleanNumberString(input: numberStr, decimalPoint: decimalPoint) else {
                    continue
                }
                
                let newT = getTransactionFromCandidate(number, candidate, numberIndexRange, image)
                transactions[newT.id] = newT
            }
        }
    }
    
    func getLineWidthFromTransactionBoundingBoxes() -> CGFloat? {
        let heights = transactionList.compactMap { $0.boundingBox?.height }
        if (heights.count == 0) {
            return nil
        }
        let medianHeight = heights.sorted()[heights.count / 2]
        var result = medianHeight / 14
        result = round(100 * result) / 100
        return max(result, 0.5)
    }
    
    func getTransactionFromCandidate(_ number: Double, _ candidate: VNRecognizedText, _ stringRange: Range<String.Index>, _ image: UIImage) -> Transaction {
        // Find the bounding-box observation for the string range.
        let boxObservation = try? candidate.boundingBox(for: stringRange)

        // Get the normalized CGRect value.
        var boundingBox = boxObservation?.boundingBox ?? .zero
        if (imageIsHeic) {
            boundingBox = heicBoundingBoxWorkaround(boundingBox)
        }
        
        // Convert the rectangle from normalized coordinates to image coordinates.
        var rect = VNImageRectForNormalizedRect(boundingBox,
                                            Int(image.size.width),
                                            Int(image.size.height))
        
        rect.origin = CGPoint(x: rect.origin.x, y: image.size.height - rect.origin.y - rect.height)
        
        return Transaction(value: number, boundingBox: rect)
    }
    
    // this can be removed if heic images no longer result in the wrong coordinates
    func heicBoundingBoxWorkaround(_ boundingBoxInHeic: CGRect) -> CGRect {
        let r = boundingBoxInHeic,
            width = r.height,
            height = r.width
        return CGRect(x: r.minY, y: 1 - r.minX - height, width: width, height: height)
    }
    
    func getNumberFromString(_ string: String) -> Double? {
        let value = Double.parse(from: string)
        return value
    }
    
    func hasTapTarget(at point: CGPoint) -> Bool {
        let tt = getTransaction(at: point)
        return tt != nil
    }
    
    func getTransaction(at point: CGPoint) -> Transaction? {
        for (_, t) in self.transactions {
            if let rect = t.boundingBox,
               rect.contains(point) {
                return t
            }
        }
        return nil
    }
    
    func hasTransaction(_ transaction: Transaction) -> Bool {
        for (_, t) in self.transactions {
            if (t == transaction) {
                return true
            }
        }
        return false
    }
    
    func getProposedMarkerRect(basedOn rect: CGRect?) -> CGRect {
        let boundingRect = getMedianBoundingBox()
        let x = (rect?.minX ?? 0) - (boundingRect.width / 2),
            y = (rect?.minY ?? 0) - (boundingRect.height / 2)
        return CGRect(x: x, y: y, width: boundingRect.width, height: boundingRect.height)
    }
    
    func getMedianBoundingBox() -> CGRect {
        let list = transactionList.filter { $0.boundingBox?.width ?? 0 > 0 && $0.boundingBox?.height ?? 0 > 0 }
        let medianWidth = list.sorted { $0.boundingBox!.width < $1.boundingBox!.width }[list.count / 2].boundingBox!.width
        let medianHeight = list.sorted { $0.boundingBox!.height < $1.boundingBox!.height }[list.count / 2].boundingBox!.height
        return CGRect(x: 0, y: 0, width: medianWidth, height: medianHeight)
    }
    
    func flashTransaction(_ transactionId: UUID, remove: Bool = false) {
        self.onFlashTransaction?(transactionId, remove)
    }
    
    func handleTap(at point: CGPoint) {
        guard let t = getTransaction(at: point),
              let onTap = onTransactionTap else {
            lastTapWasHitting = false
            emptyTapTimer = Timer.scheduledTimer(withTimeInterval: OneHandedZoomGestureRecognizer.doubleTapGestureThreshold, repeats: false) { _ in
                // Wait to see if the empty tap is just the inital zoom gesture tap
                self.onEmptyTap?()
            }
            return
        }
        lastTapWasHitting = true
        onTap(t)
    }
    
    func handleLongPress(at point: CGPoint) {
        guard let onLongPress = onImageLongPress else { return }
        let t = getTransaction(at: point)
        onLongPress(t, point)
    }
    
    
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else { return }
        DispatchQueue.main.async {
            self.storeObservationsAsTappableText(observations)
            self.lineWidth = self.getLineWidthFromTransactionBoundingBoxes()
        }
    }
    
    func processImage() {
        print("processImage")
        self.isLoadingCounter += 1
        guard let cgImage = image?.cgImage else { return }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        
        DispatchQueue.global().async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Unable to perform the requests: \(error).")
            }
            DispatchQueue.main.async {
                self.isLoadingCounter -= 1
            }
        }
    }
    
    func sum(of card: Card) -> Double {
        let transactions = card.transactionIds.compactMap { getTransaction($0) }
        let sum = transactions.compactMap { $0.getValue(for: card) }.reduce(0, +)
        return round(100 * sum) / 100
    }
    
    func sumString(of card: Card) -> String {
        return sumString(of: sum(of: card))
    }
    
    func sumString(of number: Double) -> String {
        let rounded = round(100 * number) / 100
        return String(rounded == 0 ? 0 : rounded)
    }
    
    func sortedTransactions(of card: Card) -> [UUID] {
        if (card.cardType == .total) {
            // CardType.total should have the total value on top and every user value below
            return card.transactionIds
        }
        return card.transactionIds.sorted {
            getTransaction($0)?.boundingBox?.minY ?? 0 < getTransaction($1)?.boundingBox?.minY ?? 0
        }
    }

    func getChosenCardSummary(of cards: [Card]) -> String {
        var res = ""
        let total = getTotalValue(of: cards)
        for card in cards {
            res += "\(card.name): \(sumString(of: card))\n"
        }
        res.append("\(String(localized: "total")): \(sumString(of: total))")
        return res
    }
    
    func getTotalValue(of cards: [Card]) -> Double {
        var total = 0.0
        for card in cards {
            total += sum(of: card)
        }
        return total
    }
}



extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


