

import Foundation
import SwiftUI



// MARK: Card
enum CardType: Int {
    case total
    case normal
}



enum CodingKeys: CodingKey {
    case name
    case isChosen
    case emptyText
    case cardType
    case color
}



struct Card: Identifiable, Hashable, Codable {
    let id = UUID()
    private var rawName: String
    var isActive: Bool
    var isChosen: Bool
    var transactionIds: [UUID] = []
    var emptyText: String = String(localized: "empty")
    var cardType: CardType = .normal
    
    var colorKey: ColorKeys = .neutralGray
        
    var color: CardColor {
        get {
            CardColor.get(colorKey)
        }
        set {
            self.colorKey = newValue.id
        }
    }
    
    var name: String {
        get {
            switch cardType {
            case .total:
                return String(localized: "sum")
            case .normal:
                return rawName
            }
        }
        set {
            rawName = newValue
        }
    }
    
    var stringName: String {
        if cardType != .total || !(ContentViewModel.totalTransactionId != nil && transactionIds.contains(ContentViewModel.totalTransactionId!)) {
            return name
        }
        return String(localized: "remaining")
    }
    
    var identifier: String {
        return self.id.uuidString
    }
    
    
    init(name: String, isSelected: Bool = false, transactionIds: [UUID] = [], emptyText: String? = nil) {
        self.rawName = name
        self.isActive = isSelected
        self.transactionIds = transactionIds
        self.isChosen = false
        if (emptyText != nil) {
            self.emptyText = emptyText!
        }
    }
    
    init(_ cardType: CardType) {
        switch cardType {
        case .total:
            self.init(name: "sum", emptyText: "total")
            self.colorKey = .neutralDark
            break
        case .normal:
            self.init(name: "unnamed")
        }
        self.cardType = cardType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawName = try container.decode(String.self, forKey: .name)
        isChosen = try container.decode(Bool.self, forKey: .isChosen)
        let rawCardType = try container.decode(Int.self, forKey: .cardType)
        cardType = CardType(rawValue: rawCardType) ?? .normal
        isActive = false
        do {
            let r = try container.decode(Int.self, forKey: .color)
            colorKey = ColorKeys(rawValue: r)!
        } catch {
            if (cardType == .total) {
                colorKey = .neutralDark
            } else {
                colorKey = ColorKeys.allCases.randomElement()!
            }
        }
    }


    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(isChosen, forKey: .isChosen)
        let rawCardType = cardType.rawValue
        try container.encode(rawCardType, forKey: .cardType)
        
        let r = colorKey.rawValue
        try container.encode(r, forKey: .color)
    }
    
    mutating func removeTransaction(_ transaction: Transaction) {
        transactionIds = transactionIds.filter { $0 != transaction.id }
    }
    
    mutating func clearTransactions() {
        transactionIds = []
    }
    
    mutating func addTransactionId(_ transactionId: UUID) {
        transactionIds.append(transactionId)
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(identifier)
    }
}



struct Share {
    var value: Double? = nil
    var manuallyAdjusted: Bool = false
    var cardId: UUID
    var locked: Bool = false
}



// MARK: Transaction
enum TransActionType {
    case normal
    case total
    case freeForm
    case divider
    case cardSummary
}

struct Transaction: Identifiable, Equatable {
    let id: UUID
    var rawValue: Double
    let boundingBox: CGRect?
    var type: TransActionType = .normal
    var rawLabel: String?
    var locked: Bool = false
    var shares: [UUID: Share] = [:]
    
    var value: Double {
        get {
            type == .total ? -rawValue : rawValue
        }
        set {
            if (!locked) {
                rawValue = newValue
            }
        }
    }
    
    func getValue(for card: Card) -> Double {
        shares[card.id]?.value ?? value
    }
    
    func getStringValue(for card: Card) -> String {
        let val = shares[card.id]?.value ?? value
        return String(round(100 * val) / 100)
    }
    
    var stringValue: String {
        String(round(100 * value) / 100)
    }
    
    var description: String {
        type != .divider ? "\(label ?? ""): \(value)" : ""
    }
    
    mutating func addShare(cardId: UUID, share: Double? = nil) throws {
        shares[cardId] = Share(value: share, cardId: cardId)
        try refreshShares()
    }
    
    mutating func removeShare(cardId: UUID) throws {
        shares[cardId] = nil
        try refreshShares()
    }
    
    mutating func resetShare(cardId: UUID) throws {
        shares[cardId]?.manuallyAdjusted = false
        try refreshShares()
    }
    
    mutating func editShare(cardId: UUID, value: Double?) throws {
        if (shares.count > 1 && hasOnlyOneNotManuallyAdjustedShare) {
            throw EditShareError.lastShareCannotBeAdjustedManually
        }
        if var share = shares[cardId] {
            share.value = value
            share.manuallyAdjusted = true
            shares[cardId] = share
            try refreshShares()
        } else {
            throw EditShareError.shareForCardNotFound
        }
    }
    
    var hasOnlyOneNotManuallyAdjustedShare: Bool {
        let x = shares.filter { !$0.value.manuallyAdjusted }
        return x.count == 1
    }
    
    mutating func refreshShares() throws {
        var remaining = value
        var count = 0
        for (_, share) in shares {
            if (share.manuallyAdjusted) {
                remaining -= share.value!
            } else {
                count += 1
            }
        }
        guard count > 0 else { return }
        let splits = try splitAmount(amount: remaining, numParts: count)
        for (id, share) in shares {
            if (!share.manuallyAdjusted) {
                count -= 1
                shares[id]?.value = splits[safe: count]
            }
        }
    }
    
    func splitAmount(amount: Double, numParts: Int) throws -> [Double] {
        if !(numParts > 0) { return [] }
        let x = round(amount * 100)
        if (x > Double(Int.max)) {
            throw EditShareError.numberTooLarge
        }
        let a = Int(x) // throw away more than two decimals
        var result: [Double] = []
        var remainder = a
        for i in stride(from: numParts, to: 0, by: -1) {
            let res = remainder / i
            remainder -= res
            result.append(Double(res) / 100.0)
        }
        return result
    }
    
    var label: String? {
        get {
            if (type == .total) {
                return String(localized: "total")
            } else if (shares.count > 1) {
                return String(localized: "shared")
            } else {
                return rawLabel
            }
        }
        set {
            rawLabel = newValue
        }
    }
    
    init(value: Double, boundingBox: CGRect? = nil, label: String? = nil, transactionType: TransActionType? = nil, locked: Bool? = nil, id: UUID? = nil) {
        self.rawValue = value
        self.boundingBox = boundingBox
        self.rawLabel = label
        self.type = transactionType ?? .normal
        self.locked = locked ?? false
        self.id = id ?? UUID()
    }
    
    init(from transaction: Transaction, value: Double? = nil, boundingBox: CGRect? = nil, label: String? = nil, transactionType: TransActionType? = nil, locked: Bool? = nil, id: UUID? = nil) {
        self.rawValue = value ?? transaction.value
        self.boundingBox = boundingBox ?? transaction.boundingBox
        self.rawLabel = label ?? transaction.label
        self.type = transactionType ?? transaction.type
        self.locked = locked ?? transaction.locked
        self.id = id ?? transaction.id
    }
    
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }
}


enum EditShareError: Error {
    case shareForCardNotFound
    case lastShareCannotBeAdjustedManually
    case numberTooLarge
}
