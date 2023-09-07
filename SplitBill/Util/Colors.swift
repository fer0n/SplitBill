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

struct ColorInfo {
    let dark: String
    let light: String
    let font: String
}

struct CardColor {
    var id: ColorKeys
    let dark: Color
    let light: Color
    let font: Color
    var contrast: Color = .white
    let uiColorFont: UIColor

    static let colorInfo: [ColorKeys: ColorInfo] = [
        .neutralDark: ColorInfo(dark: "cardDark", light: "cardDarkLight", font: "cardDarkFont"),
        .neutralGray: ColorInfo(dark: "cardGray", light: "cardGrayLight", font: "cardGrayFont"),
        .cardBlue: ColorInfo(dark: "cardBlue", light: "cardBlueLight", font: "cardBlueFont"),
        .cardYellow: ColorInfo(dark: "cardYellow", light: "cardYellowLight", font: "cardYellowFont"),
        .cardRed: ColorInfo(dark: "cardRed", light: "cardRedLight", font: "cardRedFont"),
        .cardLightBlue: ColorInfo(dark: "cardLightBlue", light: "cardLightBlueLight", font: "cardLightBlueFont"),
        .cardEmerald: ColorInfo(dark: "cardEmerald", light: "cardEmeraldLight", font: "cardEmeraldFont"),
        .cardThistle: ColorInfo(dark: "cardThistle", light: "cardThistleLight", font: "cardThistleFont")
    ]

    static func get(_ id: ColorKeys) -> CardColor {
        if let colorInfo = colorInfo[id] {
            let darkColor = Color(colorInfo.dark)
            let lightColor = Color(colorInfo.light)
            let fontColor = Color(colorInfo.font)
            let uiColorFont = UIColor(named: colorInfo.font) ?? UIColor(fontColor)

            return CardColor(id: id, dark: darkColor, light: lightColor, font: fontColor, uiColorFont: uiColorFont)
        } else {
            print("Error: couldn't find color \(id)")
            return CardColor(id: id, dark: .black, light: .white, font: .white, uiColorFont: .white)
        }
    }
}
