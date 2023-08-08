//
//  Colors.swift
//  SplitBill
//
//  Created by fer0n on 12.12.22.
//

import Foundation
import SwiftUI


extension Color {
    static let mainColor = Color("MainColor")
    static let markerColor = Color("MarkerColor")
    static let backgroundColor = Color(UIColor.systemGray6)
    static let foregroundColor = Color(UIColor.label)
    static let labelColor = Color("LabelColor")
}


enum ColorKeys: Int, CaseIterable {
    case neutralDark
    case cardRed
    case cardBlue
    case cardLightBlue
    case neutralGray
    case cardEmerald
    case cardYellow
    case cardThistle
}


struct CardColor {
    var id: ColorKeys
    let dark: Color
    let light: Color
    let font: Color
    var contrast: Color = .white
    
    static func get(_ id: ColorKeys) -> CardColor {
        switch(id) {
            case .neutralDark:
                let colorFont = Color("cardDarkFont")
                let color = Color("cardDark")
            return CardColor(id: .neutralDark, dark: color, light: Color.black, font: colorFont)
            case .neutralGray:
            return CardColor(id: .neutralGray, dark: Color.gray, light: Color.white, font: Color.foregroundColor, contrast: .black)
            case .cardBlue:
                let color = Color("cardBlue")
                let colorFont = Color("cardBlueFont")
                let colorLight = Color("cardBlueLight")
                return CardColor(id: .cardBlue, dark: color, light: colorLight, font: colorFont)
            case .cardYellow:
                let color = Color("cardYellow")
                let colorLight = Color("cardYellowLight")
                let colorFont = Color("cardYellowFont")
                return CardColor(id: .cardYellow, dark: color, light: colorLight, font: colorFont)
            case .cardRed:
                let color = Color("cardRed")
                let colorFont = Color("cardRedFont")
                let colorLight = Color("cardRedLight")
                return CardColor(id: .cardRed, dark: color, light: colorLight, font: colorFont)
            case .cardLightBlue:
                let color = Color("cardLightBlue")
                let colorFont = Color("cardLightBlueFont")
                let colorLight = Color("cardLightBlueLight")
                return CardColor(id: .cardLightBlue, dark: color, light: colorLight, font: colorFont)
            case .cardEmerald:
                let color = Color("cardEmerald")
                let colorLight = Color("cardEmeraldLight")
                let colorFont = Color("cardEmeraldFont")
                return CardColor(id: .cardEmerald, dark: color, light: colorLight, font: colorFont)
            case .cardThistle:
                let color = Color("cardThistle")
                let colorFont = Color("cardThistleFont")
                let colorLight = Color("cardThistleLight")
                return CardColor(id: .cardThistle, dark: color, light: colorLight, font: colorFont)
        }
    }
}
