

import Foundation
import SwiftUI



// MARK: Card
enum CardType: Int {
    case total
    case normal
}



enum CardCodingKeys: CodingKey {
    case id
    case name
    case isChosen
    case emptyText
    case cardType
    case color
    case transactionIds
}



struct Card: Identifiable, Hashable, Codable {
    let id: UUID
    private var rawName: String
    var isActive: Bool
    var isChosen: Bool
    var transactionIds: [UUID] = []
    var emptyText: String = "empty"
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
        self.id = UUID()
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
        let container = try decoder.container(keyedBy: CardCodingKeys.self)
        rawName = try container.decode(String.self, forKey: .name)
        isChosen = try container.decode(Bool.self, forKey: .isChosen)
        let rawCardType = try container.decode(Int.self, forKey: .cardType)
        cardType = CardType(rawValue: rawCardType) ?? .normal
        isActive = false
        do {
            id = try container.decode(UUID.self, forKey: .id)
        } catch {
            id = UUID()
            print("no id found")
        }
        do {
            transactionIds = try container.decode([UUID].self, forKey: .transactionIds)
        } catch {
            print("couldn't load transactionIds: \(error)")
        }
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
        var container = encoder.container(keyedBy: CardCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isChosen, forKey: .isChosen)
        let rawCardType = cardType.rawValue
        try container.encode(rawCardType, forKey: .cardType)
        try container.encode(transactionIds, forKey: .transactionIds)
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
