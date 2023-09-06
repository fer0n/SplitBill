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
    static let exportCardBackground = Color("exportCardBackground")
    static let exportCardSeperator = Color("exportCardSeperator")
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
    let uiColorFont: UIColor
    
    static func get(_ id: ColorKeys) -> CardColor {
        switch(id) {
            case .neutralDark:
                let colorFont = Color("cardDarkFont")
                let uiColorFont = UIColor(named: "cardDarkFont")
                let color = Color("cardDark")
            return CardColor(id: .neutralDark, dark: color, light: Color.black, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
            case .neutralGray:
            return CardColor(id: .neutralGray, dark: Color.gray, light: Color.gray, font: Color.white, contrast: .white, uiColorFont: UIColor(named: "ForegroundColor") ?? UIColor(Color.white))
            case .cardBlue:
                let color = Color("cardBlue")
                let colorFont = Color("cardBlueFont")
                let uiColorFont = UIColor(named: "cardBlueFont")
                let colorLight = Color("cardBlueLight")
                return CardColor(id: .cardBlue, dark: color, light: colorLight, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
            case .cardYellow:
                let color = Color("cardYellow")
                let colorLight = Color("cardYellowLight")
                let uiColorFont = UIColor(named: "cardYellowFont")
                let colorFont = Color("cardYellowFont")
                return CardColor(id: .cardYellow, dark: color, light: colorLight, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
            case .cardRed:
                let color = Color("cardRed")
                let colorFont = Color("cardRedFont")
                let uiColorFont = UIColor(named: "cardRedFont")
                let colorLight = Color("cardRedLight")
                return CardColor(id: .cardRed, dark: color, light: colorLight, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
            case .cardLightBlue:
                let color = Color("cardLightBlue")
                let colorFont = Color("cardLightBlueFont")
                let uiColorFont = UIColor(named: "cardLightBlueFont")
                let colorLight = Color("cardLightBlueLight")
                return CardColor(id: .cardLightBlue, dark: color, light: colorLight, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
            case .cardEmerald:
                let color = Color("cardEmerald")
                let colorLight = Color("cardEmeraldLight")
                let uiColorFont = UIColor(named: "cardEmeraldFont")
                let colorFont = Color("cardEmeraldFont")
                return CardColor(id: .cardEmerald, dark: color, light: colorLight, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
            case .cardThistle:
                let color = Color("cardThistle")
                let colorFont = Color("cardThistleFont")
                let uiColorFont = UIColor(named: "cardThistleFont")
                let colorLight = Color("cardThistleLight")
                return CardColor(id: .cardThistle, dark: color, light: colorLight, font: colorFont, uiColorFont: uiColorFont ?? UIColor(colorFont))
        }
    }
}
