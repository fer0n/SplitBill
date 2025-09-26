//
//  FloatingTransactionInfo.swift
//  SplitBill
//

import SwiftUI

struct FloatingTransactionInfo {
    init(center: Bool, width: CGFloat?, value: String, color: ColorKeys, cardColors: [Color] = []) {
        self.center = center
        self.width = width
        self.value = value
        self.cardColors = cardColors
        self.colorKey = color
    }

    var center: Bool
    var width: CGFloat?
    var padding: CGFloat = 0
    var value: String
    var colorKey: ColorKeys
    var editable = false
    var cardColors: [Color]
    var uiFont: UIFont = UIFont.rounded(ofSize: 20, weight: .semibold)

    var color: CardColor {
        get {
            CardColor.get(colorKey)
        }
        set {
            self.colorKey = newValue.id
        }
    }
}
