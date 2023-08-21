//
//  TransactionModel.swift
//  SplitBill
//
//  Created by fer0n on 21.08.23.
//

import Foundation
import SwiftUI



// MARK: Share
struct Share: Codable {
    var value: Double? = nil
    var manuallyAdjusted: Bool = false
    var cardId: UUID
    var locked: Bool = false
}


enum EditShareError: Error {
    case shareForCardNotFound
    case lastShareCannotBeAdjustedManually
    case numberTooLarge
}



// MARK: Transaction
enum TransActionType: Int {
    case normal
    case total
    case freeForm
    case divider
    case cardSummary
}

enum TransactionCodingKeys: CodingKey {
        case id
        case rawValue
        case boundingBox
        case type
        case rawLabel
        case locked
        case shares
    }

struct Transaction: Identifiable, Equatable, Codable {
    let id: UUID
    var rawValue: Double
    let boundingBox: CGRect?
    var type: TransActionType = .normal
    var rawLabel: String?
    var locked: Bool = false
    var shares: [UUID: Share] = [:]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TransactionCodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        rawValue = try container.decode(Double.self, forKey: .rawValue)
        boundingBox = try container.decodeIfPresent(CGRect.self, forKey: .boundingBox)
        let rawTransactionType = try container.decode(Int.self, forKey: .type)
        type = TransActionType(rawValue: rawTransactionType) ?? .normal
        rawLabel = try container.decodeIfPresent(String.self, forKey: .rawLabel)
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        shares = try container.decodeIfPresent([UUID: Share].self, forKey: .shares) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TransactionCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(rawValue, forKey: .rawValue)
        try container.encodeIfPresent(boundingBox, forKey: .boundingBox)
        let rawTransactionType = type.rawValue
        try container.encode(rawTransactionType, forKey: .type)
        try container.encodeIfPresent(rawLabel, forKey: .rawLabel)
        try container.encodeIfPresent(locked, forKey: .locked)
        try container.encode(shares, forKey: .shares)
    }
    
    
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
        guard var share = shares[cardId] else {
            throw EditShareError.shareForCardNotFound
        }
        if (!share.manuallyAdjusted && shares.count > 1 && hasOnlyOneNotManuallyAdjustedShare) {
            throw EditShareError.lastShareCannotBeAdjustedManually
        }
        
        share.value = value
        share.manuallyAdjusted = true
        shares[cardId] = share
        try refreshShares()
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

